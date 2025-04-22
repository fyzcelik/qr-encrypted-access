import cv2
import hashlib
import base64
import json
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def derive_key_from_school_name(school_name):
    return hashlib.sha256(school_name.encode()).digest()

def read_qr(filename):
    img = cv2.imread(filename)
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(img)
    return data if data else None

def decrypt_message(encrypted_json, key):
    try:
        data = json.loads(encrypted_json)

        nonce = base64.b64decode(data['nonce'])
        ciphertext = base64.b64decode(data['cipher'])

        aesgcm = AESGCM(key)
        decrypted = aesgcm.decrypt(nonce, ciphertext, None)
        return decrypted.decode()
    except Exception as e:
        print(f"[!] Şifre çözme hatası: {e}")
        return None

if __name__ == "__main__":
    qr_dosya = input("QR kod dosya adını girin: ")
    okul_no = input("Okul numaranızı girin: ").strip()

    with open("student_ids.json", "r") as f:
        student_map = {k.strip(): v.strip() for k, v in json.load(f).items()}

    school_name = student_map.get(okul_no)
    if not school_name:
        print("Bu öğrenci numarasına ait kayıt bulunamadı.")
        exit()

    key = derive_key_from_school_name(school_name)

    qr_data = read_qr(qr_dosya)
    if qr_data:
        result = decrypt_message(qr_data, key)
        if result:
            print(f"Mesaj başarıyla çözüldü: {result}")
        else:
            print("Mesaj çözülemedi. Okul numarası veya veri hatalı olabilir.")
    else:
        print("QR koddan veri alınamadı.")
