"""Separate ruler references, raw calibration evidence, and display validity."""
import argparse
import csv
import datetime
import hashlib
import json
import re
import statistics
from pathlib import Path


def ungray(value):
    result = value
    while value:
        value >>= 1
        result ^= value
    return result


def decode(path, extended=False, allow_zero=False):
    with path.open(newline='', encoding='utf-8-sig') as stream:
        all_rows = list(csv.reader(stream))
    headers, rows = all_rows[0], all_rows[2:]
    columns = [(i, name) for i, name in enumerate(headers) if 'diagnostic_bus' in name]
    if not columns:
        raise ValueError('Expected diagnostic bus in ILA export')
    if len(columns) == 1:
        values = [int(row[columns[0][0]], 16) for row in rows if row]
    elif extended and len(columns) == 2:
        # Vivado may publish the two noncontiguous net ranges as separate probes.
        offsets = {}
        for i, name in columns:
            interval = re.search(r'\[(\d+):(\d+)\]', name)
            if not interval or interval.groups() not in [('255', '0'), ('447', '384'), ('479', '384')]:
                raise ValueError('Unexpected split ROI probe layout')
            offsets[i] = 0 if interval.group(2) == '0' else 256
        if set(offsets.values()) != {0, 256}:
            raise ValueError('Duplicate split probe')
        values = [sum(int(row[i], 16) << offset for i, offset in offsets.items())
                  for row in rows if row]
    else:
        raise ValueError('Unexpected diagnostic probe columns')
    if len(values) != 1024:
        raise ValueError(f'Incomplete capture: {path.name}: {len(values)}')
    value = values[0]
    bits = lambda offset, size: (value >> offset) & ((1 << size) - 1)
    result = {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
              'flags': bits(0, 8), 'chip1': bits(8, 16), 'chip2': bits(24, 16),
              'lcd': bits(40, 16), 'frame1': ungray(bits(56, 8)),
              'frame2': ungray(bits(64, 8)), 'pixels1': bits(104, 20),
              'pixels2': bits(124, 20), 'ticks_hi': bits(192, 16),
              'dominant_disparity_px': bits(208, 6),
              'raw_distance_cm': bits(214, 16), 'distance_valid': bool(bits(230, 1))}
    result['hardware_identity_ok'] = (result['flags'] & 15 == 15 and
        [result['chip1'], result['chip2'], result['lcd']] == [0x5640, 0x5640, 0x4384] and
        result['pixels1'] == result['pixels2'] == 192000)
    if extended:
        result.update(roi_reason=bits(256, 4), roi_population=bits(260, 12),
                      roi_samples=bits(272, 12), roi_peak=bits(284, 12),
                      roi_weighted=bits(296, 20))
        n, w = result['roi_samples'], result['roi_weighted']
        result['mean_disparity_px'] = w / n if n else None
        result['match_quality_passed'] = bool(n >= 24 and result['roi_peak'] >= 24 and
            n * 2 >= result['roi_population'] and (allow_zero or w > 0) and result['roi_reason'] in (4, 5, 6))
    return result


def summarize(samples, measured_cm):
    if len(samples) != 3 or not 30 <= measured_cm <= 200:
        raise ValueError('Exactly three captures and ruler distance 30..200cm required')
    accepted = [s['raw_distance_cm'] for s in samples
                if s['distance_valid'] and s['hardware_identity_ok']]
    errors = [distance - measured_cm for distance in accepted]
    median = statistics.median(accepted) if accepted else None
    independent = all(a['frame1'] != b['frame1'] and a['frame2'] != b['frame2']
                      for a, b in zip(samples, samples[1:]))
    identity_ok = all(s['hardware_identity_ok'] for s in samples)
    quality_ok = all(s.get('match_quality_passed', False) for s in samples)
    disparities = [s.get('mean_disparity_px') for s in samples]
    boundary = any(d is not None and (d <= 1 or d >= 62) for d in disparities)
    raw = [s['raw_distance_cm'] for s in samples]
    return {'measured_cm': measured_cm, 'sample_count': 3, 'valid_count': len(accepted),
            'reference_distance_cm': measured_cm,
            'reference_source': 'user_confirmed_ruler_distance',
            'display_valid_count': len(accepted),
            'display_valid_median_cm': median,
            'raw_register_readings_cm': raw,
            'raw_register_median_cm': statistics.median(raw),
            'reference_record_preserved': True,
            'calibration_capture_checks_passed': bool(identity_ok and independent and quality_ok),
            'search_boundary_review_required': boundary,
            'eligible_for_disparity_fit': bool(identity_ok and independent and quality_ok and not boundary),
            'calibration_note': 'A rejected display flag does not invalidate the known reference distance or raw calibration evidence.',
            'distinct_adjacent_camera_frames': independent, 'samples': samples,
            'valid_readings_cm': accepted, 'signed_errors_cm': errors,
            'median_cm': median,
            'median_error_cm': median - measured_cm if median is not None else None,
            'max_abs_error_cm': max(map(abs, errors)) if errors else None,
            'group_all_three_within_2cm': bool(len(accepted) == 3 and independent and
                max(map(abs, errors)) <= 2),
            'scope': 'frontal static target only; three snapshots, not whole-range or dynamic proof'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('folder', type=Path)
    parser.add_argument('--measured-cm', required=True, type=float)
    args = parser.parse_args()
    meta = (args.folder / 'capture_meta.txt').read_text(encoding='utf-8')
    extended = any(name in meta for name in ('build=front_range_20261103',
                  'build=front_fit_20261103', 'probe_layout=compact256_roi64'))
    samples = [decode(args.folder / f'capture_{i}.csv', extended,
                      'allow_zero_disparity=1' in meta)
               for i in range(3)]
    result = summarize(samples, args.measured_cm)
    result['capture_metadata'] = meta
    result['created'] = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()
    (args.folder / 'group.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k not in ('samples', 'capture_metadata')},
                     ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
