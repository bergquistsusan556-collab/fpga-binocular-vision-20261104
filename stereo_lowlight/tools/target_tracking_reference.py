"""Host-only algorithm reference; NOT FPGA RTL or a replacement for LCD firmware."""
import cv2
import numpy as np

class TargetTracker:
    def __init__(self):
        p=cv2.aruco.DetectorParameters()
        p.cornerRefinementMethod=cv2.aruco.CORNER_REFINE_SUBPIX
        p.cornerRefinementWinSize=3
        self.detector=cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50),p)

    def locate(self,image):
        corners,ids,_=self.detector.detectMarkers(image)
        if ids is None:return None
        hits=[c.reshape(4,2) for c,i in zip(corners,ids.ravel()) if i==7]
        # No persistence of old boxes; duplicate identity is ambiguous.
        if len(hits)!=1:return None
        c=hits[0]
        return {'corners':c,'center':c.mean(axis=0),'box':np.r_[c.min(axis=0),c.max(axis=0)]}

    def measure(self,left,right,P1=None,P2=None):
        """Images must already be rectified with measured calibration matrices.
        P matrices must use millimetres. Caller must supply time-matched frames.
        """
        a,b=self.locate(left),self.locate(right)
        result={'left':a,'right':b,'distance_mm':None,'valid':False}
        if a is None or b is None or P1 is None or P2 is None:return result
        if np.max(np.abs(a['corners'][:,1]-b['corners'][:,1]))>1.5:return result
        h=cv2.triangulatePoints(P1,P2,a['corners'].T,b['corners'].T)
        if np.any(np.abs(h[3])<1e-9):return result
        xyz=(h[:3]/h[3]).T
        if not np.isfinite(xyz).all() or np.any(xyz[:,2]<=0):return result
        # Check reprojection and known target size instead of displaying guesses.
        for P,obs in ((P1,a['corners']),(P2,b['corners'])):
            q=P@np.c_[xyz,np.ones(4)].T
            if np.max(np.linalg.norm((q[:2]/q[2]).T-obs,axis=1))>1:return result
        sides=np.linalg.norm(xyz-np.roll(xyz,1,axis=0),axis=1)
        if np.max(np.abs(sides-160))>32:return result
        z=float(np.mean(xyz[:,2]))
        result['raw_distance_mm']=z
        if 300<=z<=2000:result.update(distance_mm=z,valid=True)
        return result
