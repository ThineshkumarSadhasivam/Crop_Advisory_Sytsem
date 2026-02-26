from flask import Flask, request, jsonify
import joblib

app = Flask(__name__)

model = joblib.load("crop_model.pkl")

@app.route('/predict', methods=['POST'])
def predict():

    data = request.json

    prediction = model.predict([[
        data['N'],
        data['P'],
        data['K'],
        data['temperature'],
        data['humidity'],
        data['ph'],
        data['rainfall']
    ]])

    return jsonify({
        "crop": prediction[0]
    })


app.run(port=5000)