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
        student_map = {k.strip(): v.strip() for k, v in json.load(f).items()}

    student_id = student_id.strip()
    school_name = student_map.get(student_id)
    if not school_name:
        raise ValueError("Bu öğrenci numarasına ait okul bilgisi bulunamadı.")

    key = derive_key_from_school_name(school_name)
    aesgcm = AESGCM(key)

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

    kapak_dosya = input("QR kod hangi görselin içine gizlensin? ")
    cikti_dosya = "gizli_kapak.png"
    hide_qr_in_image("gizli_qr.png", kapak_dosya, cikti_dosya)

from PIL import Image

def hide_qr_in_image(qr_path, cover_path, output_path):
    qr_img = Image.open(qr_path).convert("1")  # siyah-beyaz
    cover_img = Image.open(cover_path).convert("RGB")

    qr_img = qr_img.resize(cover_img.size)
    qr_pixels = qr_img.load()
    cover_pixels = cover_img.load()

    for y in range(cover_img.height):
        for x in range(cover_img.width):
            r, g, b = cover_pixels[x, y]
            bit = 1 if qr_pixels[x, y] == 0 else 0  # siyah: 0, beyaz: 1
            r = (r & ~1) | bit
            cover_pixels[x, y] = (r, g, b)

    cover_img.save(output_path)
    print(f"[+] QR kod gizlenmiş görsel oluşturuldu: {output_path}")
