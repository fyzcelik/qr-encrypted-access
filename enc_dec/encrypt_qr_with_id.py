import hashlib
import base64
import cv2
import numpy as np
from PIL import Image
from cryptography.fernet import Fernet

def create_key_from_id(student_id):
    hash = hashlib.sha256(student_id.encode()).digest()
    key = base64.urlsafe_b64encode(hash)
    return Fernet(key)

def encrypt_message_with_id(message, student_id):
    cipher = create_key_from_id(student_id)
    encrypted = cipher.encrypt(message.encode())
    return encrypted

def generate_qr(data, filename="gizli_qr.png"):
    import qrcode
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(data.decode())
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    img.save(filename)
    print(f"[+] QR kod oluşturuldu: {filename}")

if __name__ == "__main__":
    mesaj = input("Gizlenecek mesajı girin: ")
    okul_no = input("QR kod sadece hangi okul numarasıyla çözülecek? ")

    encrypted_data = encrypt_message_with_id(mesaj, okul_no)
    generate_qr(encrypted_data)
