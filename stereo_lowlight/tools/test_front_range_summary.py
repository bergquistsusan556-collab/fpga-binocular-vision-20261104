import unittest
import csv
import tempfile
from pathlib import Path
from front_range_summary import summarize, decode


class FrontRangeSummaryTests(unittest.TestCase):
    def rows(self, readings, valid=None):
        valid = [True] * 3 if valid is None else valid
        return [dict(raw_distance_cm=v, distance_valid=ok, hardware_identity_ok=True,
                     frame1=i, frame2=i) for i, (v, ok) in enumerate(zip(readings, valid))]

    def test_median_does_not_conceal_outlier(self):
        result = summarize(self.rows([99, 100, 130]), 100)
        self.assertEqual(result['median_cm'], 100)
        self.assertEqual(result['max_abs_error_cm'], 30)
        self.assertFalse(result['group_all_three_within_2cm'])

    def test_invalid_distance_preserved_but_not_accepted(self):
        result = summarize(self.rows([30, 1, 31], [True, False, True]), 30)
        self.assertEqual(result['valid_count'], 2)
        self.assertEqual(result['samples'][1]['raw_distance_cm'], 1)
        self.assertFalse(result['group_all_three_within_2cm'])

    def test_all_invalid_has_no_median(self):
        result = summarize(self.rows([0, 0, 0], [False] * 3), 100)
        self.assertIsNone(result['median_cm'])
        self.assertIsNone(result['max_abs_error_cm'])

    def test_display_guard_does_not_discard_calibration_reference(self):
        rows = self.rows([275, 277, 277], [False] * 3)
        for row in rows:
            row.update(match_quality_passed=True, mean_disparity_px=4.0)
        result = summarize(rows, 150)
        self.assertEqual(result['reference_distance_cm'], 150)
        self.assertEqual(result['raw_register_median_cm'], 277)
        self.assertEqual(result['display_valid_count'], 0)
        self.assertTrue(result['calibration_capture_checks_passed'])
        self.assertTrue(result['eligible_for_disparity_fit'])
        self.assertFalse(result['group_all_three_within_2cm'])

    def test_boundary_review_preserves_measured_reference(self):
        rows = self.rows([18, 18, 18], [False] * 3)
        for row in rows:
            row.update(match_quality_passed=True, mean_disparity_px=63.0)
        result = summarize(rows, 30)
        self.assertEqual(result['reference_distance_cm'], 30)
        self.assertTrue(result['reference_record_preserved'])
        self.assertTrue(result['search_boundary_review_required'])
        self.assertFalse(result['eligible_for_disparity_fit'])

    def test_accept_both_measured_endpoints(self):
        for cm in [30, 200]:
            result = summarize(self.rows([cm - 2, cm, cm + 2]), cm)
            self.assertTrue(result['group_all_three_within_2cm'])

    def test_duplicate_frames_fail(self):
        rows = self.rows([100, 100, 100])
        rows[1]['frame1'] = rows[0]['frame1']
        self.assertFalse(summarize(rows, 100)['group_all_three_within_2cm'])

    def test_require_three_and_measured_range(self):
        for rows, cm in [(self.rows([100, 100, 100])[:2], 100),
                         (self.rows([100, 100, 100]), 29)]:
            with self.assertRaises(ValueError):
                summarize(rows, cm)

    def test_real_compact_capture_layout(self):
        root = Path(__file__).resolve().parents[1]
        row = decode(root / 'build/video_fusion/selected/capture_0.csv')
        self.assertTrue(row['hardware_identity_ok'])
        self.assertEqual(row['pixels1'], 192000)

    def test_split_roi_probe_export(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'capture.csv'
            roi = 6 | (100 << 4) | (80 << 16) | (60 << 28) | (800 << 40)
            low = 15 | (0x5640 << 8) | (0x5640 << 24) | (0x4384 << 40)
            low |= (192000 << 104) | (192000 << 124) | (100 << 214) | (1 << 230)
            with path.open('w', newline='') as stream:
                writer = csv.writer(stream)
                writer.writerow(['Sample in Buffer', 'diagnostic_bus[447:384]', 'diagnostic_bus[255:0]'])
                writer.writerow(['UNSIGNED', 'HEX', 'HEX'])
                writer.writerows([[i, f'{roi:x}', f'{low:x}'] for i in range(1024)])
            result = decode(path, extended=True)
            self.assertEqual(result['mean_disparity_px'], 10)
            self.assertTrue(result['match_quality_passed'])
            self.assertEqual(result['raw_distance_cm'], 100)

    def test_observer_extension_preserves_zero_disparity_and_roi(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'capture.csv'
            roi = 6 | (100 << 4) | (100 << 16) | (100 << 28)
            observer = 0xCA8006F2
            low = 15 | (0x5640 << 8) | (0x5640 << 24) | (0x4384 << 40)
            low |= (192000 << 104) | (192000 << 124) | (210 << 214) | (1 << 230)
            with path.open('w', newline='') as stream:
                writer = csv.writer(stream)
                writer.writerow(['Sample', 'diagnostic_bus[479:384]', 'diagnostic_bus[255:0]'])
                writer.writerow(['UNSIGNED', 'HEX', 'HEX'])
                writer.writerows([[i, f'{(observer << 64) | roi:x}', f'{low:x}'] for i in range(1024)])
            result = decode(path, extended=True, allow_zero=True)
            self.assertEqual(result['mean_disparity_px'], 0)
            self.assertEqual(result['roi_samples'], 100)
            self.assertTrue(result['match_quality_passed'])
            self.assertFalse(decode(path, extended=True)['match_quality_passed'])


if __name__ == '__main__':
    unittest.main()
