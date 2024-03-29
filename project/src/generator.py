import numpy as np
from scale import Scale
from chain import Chain


class Generator(object):

    def __init__(self):
        self.chain = Chain().make()
        self.angle_scale    = Scale([-1.0, 1.0], [-0.5, 0.5])
        self.position_scale = Scale([-3.0, 3.0], [-0.5, 0.5])

    def generate_angles(self):
        theta1 = np.random.uniform(-1.0, 1.0)
        theta2 = np.random.uniform(-1.0, 1.0)
        theta3 = np.random.uniform(-1.0, 1.0)
        return [theta1, theta2, theta3]

    def scale_angles(self, a):
        theta1 = self.angle_scale.forward_scale(a[0])
        theta2 = self.angle_scale.forward_scale(a[1])
        theta3 = self.angle_scale.forward_scale(a[2])
        return [theta1, theta2, theta3]

    def generate_positions(self, a):
        p = self.chain.forward({
            'theta1': a[0], 
            'theta2': a[1], 
            'theta3': a[2]
        })
        return([p[0], p[1], p[2]])

    def scale_positions(self, p):
        p0 = self.position_scale.forward_scale(p[0])
        p1 = self.position_scale.forward_scale(p[1])
        p2 = self.position_scale.forward_scale(p[2])
        return [p0, p1, p2]

    def make(self, batch_size):
        while 1:
            features = []
            labels   = []
            for i in range(batch_size):
                angles    = self.generate_angles()
                positions = self.generate_positions(angles)
                features.append(self.scale_positions(positions))
                labels.append(self.scale_angles(angles))
            yield np.array([features, labels])

