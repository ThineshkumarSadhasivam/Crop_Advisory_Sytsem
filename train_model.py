import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
import joblib

# Load dataset
data = pd.read_csv("Crop_recommendation.csv")

# Input Features
X = data[['N','P','K','temperature','humidity','ph','rainfall']]

# Output Label
y = data['label']

# Split dataset
X_train, X_test, y_train, y_test = train_test_split(X,y,test_size=0.2)

# Train model
model = RandomForestClassifier(n_estimators=100)

model.fit(X_train,y_train)

# Save model
joblib.dump(model,"crop_model.pkl")

print("Crop Model Created Successfully 🌱")