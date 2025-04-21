import hashlib
import base64
import json
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os
import qrcode

def derive_key_from_school_name(school_name):
    # SHA256 ile anahtarı türet, 32 byte olarak al (AES-256 için)
    return hashlib.sha256(school_name.encode()).digest()

def encrypt_message_with_id(message, student_id):
    with open("student_ids.json", "r") as f:
        student_map = json.load(f)

    school_name = student_map.get(student_id)
    if not school_name:
        raise ValueError("Bu öğrenci numarasına ait okul bilgisi bulunamadı.")

    key = derive_key_from_school_name(school_name)
    aesgcm = AESGCM(key)

    # 12 byte'lık rastgele nonce oluştur
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, message.encode(), None)

    # QR'a koymak için JSON formatında hepsini base64 olarak encode et
    payload = {
        'nonce': base64.b64encode(nonce).decode(),
        'cipher': base64.b64encode(ciphertext).decode()
    }

    return json.dumps(payload)

def generate_qr(data, filename="gizli_qr.png"):
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(data)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    img.save(filename)
    print(f"[+] QR kod oluşturuldu: {filename}")

if __name__ == "__main__":
    mesaj = input("Gizlenecek mesajı girin: ")
    okul_no = input("QR kod sadece hangi okul numarasıyla çözülecek? ")

    encrypted_json = encrypt_message_with_id(mesaj, okul_no)
    generate_qr(encrypted_json)
