from fastapi import FastAPI, File, Form, UploadFile
import cv2
import hashlib
import base64
from cryptography.fernet import Fernet
import shutil

app = FastAPI()

def create_key_from_id(student_id: str):
    hash_val = hashlib.sha256(student_id.encode()).digest()
    return base64.urlsafe_b64encode(hash_val)

def extract_encrypted_message_from_qr(file_path: str):
    img = cv2.imread(file_path)
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(img)
    if data:
        return data.encode()  # Fernet expects bytes
    return None

@app.post("/decrypt_qr/")
async def decrypt_qr(student_id: str = Form(...), qr_file: UploadFile = File(...)):
    # Geçici olarak QR dosyasını kaydet
    file_location = f"temp_{qr_file.filename}"
    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(qr_file.file, buffer)

    try:
        encrypted_data = extract_encrypted_message_from_qr(file_location)
        if encrypted_data is None:
            return {"success": False, "message": "QR koddan veri okunamadı"}

        key = create_key_from_id(student_id)
        cipher = Fernet(key)

        decrypted = cipher.decrypt(encrypted_data).decode()
        return {"success": True, "message": decrypted}

    except Exception as e:
        return {"success": False, "message": "Çözümleme başarısız. Anahtar veya QR hatalı."}
