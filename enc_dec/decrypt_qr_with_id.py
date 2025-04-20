import cv2
import hashlib
import base64
from cryptography.fernet import Fernet

def create_key_from_id(student_id):
    hash = hashlib.sha256(student_id.encode()).digest()
    key = base64.urlsafe_b64encode(hash)
    return Fernet(key)

def read_qr(filename):
    img = cv2.imread(filename)
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(img)
    if data:
        return data.encode()  # Fernet expects bytes
    return None

if __name__ == "__main__":
    qr_dosya = input("QR kod dosya adını girin: ")
    okul_no = input("Okul numaranızı girin: ")

    encrypted_data = read_qr(qr_dosya)
    if encrypted_data:
        try:
            cipher = create_key_from_id(okul_no)
            decrypted = cipher.decrypt(encrypted_data).decode()
            print(f"Mesaj başarıyla çözüldü: {decrypted}")
        except Exception as e:
            print("Mesaj çözülemedi. Okul numarası yanlış olabilir.")
    else:
        print("QR koddan veri alınamadı.")
