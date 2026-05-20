import numpy as np


class LinearRegressionArtifact:
    def __init__(self, feature_columns, coefficients, intercept):
        self.feature_columns = list(feature_columns)
        self.coefficients = np.array(coefficients, dtype=float)
        self.intercept = float(intercept)

    def predict(self, rows):
        if hasattr(rows, "loc"):
            matrix = rows[self.feature_columns].to_numpy(dtype=float)
        else:
            matrix = np.array(rows, dtype=float)
        return matrix @ self.coefficients + self.intercept
