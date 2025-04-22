from fastapi import FastAPI, File, Form, UploadFile
import cv2
import hashlib
import base64
import json
import shutil
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

app = FastAPI()

def derive_key_from_school(school_name: str) -> bytes:
    return hashlib.sha256(school_name.encode()).digest()  # 32 byte AES-GCM key

def extract_encrypted_message_from_qr(file_path: str):
    img = cv2.imread(file_path)
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(img)
    return data if data else None

@app.post("/decrypt_qr/")
async def decrypt_qr(student_id: str = Form(...), qr_file: UploadFile = File(...)):
    file_location = f"temp_{qr_file.filename}"
    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(qr_file.file, buffer)

    try:
        # QR koddan base64 JSON formatında veri oku
        encrypted_json = extract_encrypted_message_from_qr(file_location)
        if encrypted_json is None:
            return {"success": False, "message": "QR koddan veri okunamadı."}

        # Öğrenci ID'ye göre okul adı al
        with open("student_ids.json", "r") as f:
            student_map = json.load(f)

        school_name = student_map.get(student_id.strip())  
        if not school_name:
            return {"success": False, "message": f"Öğrenci numarası ({student_id}) bulunamadı."}

        key = derive_key_from_school(school_name)
  
        encrypted_data = json.loads(encrypted_json)

        if "nonce" not in encrypted_data or "cipher" not in encrypted_data:
            return {"success": False, "message": "QR içeriği geçerli değil."}

        nonce = base64.b64decode(encrypted_data["nonce"])
        cipher_text = base64.b64decode(encrypted_data["cipher"])

        aesgcm = AESGCM(key)
        decrypted = aesgcm.decrypt(nonce, cipher_text, None).decode()

        return {"success": True, "message": decrypted}

    except Exception as e:
        return {"success": False, "message": f"Çözümleme başarısız: {str(e)}"}