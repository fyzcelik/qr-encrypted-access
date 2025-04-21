import cv2
import hashlib
import base64
import json
from cryptography.fernet import Fernet

def create_key_from_school_name(school_name):
    hash_bytes = hashlib.sha256(school_name.encode()).digest()  # 32 bytes
    key = base64.urlsafe_b64encode(hash_bytes)[:32]  # Trim to 32 bytes for AES-GCM
    return Fernet(base64.urlsafe_b64encode(key))  # Re-encode as Fernet expects base64

def read_qr(filename):
    img = cv2.imread(filename)
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(img)
    if data:
        return data.encode() 
    return None

if __name__ == "__main__":
    qr_dosya = input("QR kod dosya adını girin: ")
    okul_no = input("Okul numaranızı girin: ")

    # Load student ID to school mapping
    with open("student_ids.json", "r") as f:
        student_map = json.load(f)

    school_name = student_map.get(okul_no)
    if not school_name:
        print("Bu öğrenci numarasına ait kayıt bulunamadı.")
        exit()

    encrypted_data = read_qr(qr_dosya)
    if encrypted_data:
        try:
            cipher = create_key_from_school_name(school_name)
            decrypted = cipher.decrypt(encrypted_data).decode()
            print(f"Mesaj başarıyla çözüldü: {decrypted}")
        except Exception as e:
            print("Mesaj çözülemedi. Okul numarası veya şifre yanlış olabilir.")
    else:
        print("QR koddan veri alınamadı.")
