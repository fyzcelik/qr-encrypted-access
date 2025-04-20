import qrcode
import hashlib
import base64
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
    qr = qrcode.make(data.decode())
    qr.save(filename)
    print(f"[+] QR kod oluşturuldu: {filename}")

if __name__ == "__main__":
    mesaj = input("Gizlenecek mesajı girin: ")
    okul_no = input("QR kod sadece hangi okul numarasıyla çözülecek? ")

    encrypted_data = encrypt_message_with_id(mesaj, okul_no)
    generate_qr(encrypted_data)
