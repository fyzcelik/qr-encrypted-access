import cv2
import hashlib
import base64
import json
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def extract_qr_from_image(cover_image_path, output_qr_path):
    cover_img = cv2.imread(cover_image_path)
    if cover_img is None:
        print("[!] Görsel yüklenemedi.")
        return False

    # Gizlenmiş QR kod LSB yöntemine göre kırmızı kanalın en düşük bitine saklanmış varsayılıyor
    height, width, _ = cover_img.shape
    qr_img = cv2.cvtColor(cover_img, cv2.COLOR_BGR2GRAY)

    for y in range(height):
        for x in range(width):
            lsb = cover_img[y, x, 2] & 1  # kırmızı kanal
            qr_img[y, x] = 255 if lsb else 0

    cv2.imwrite(output_qr_path, qr_img)
    return True

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
    kapak_dosya = input("QR kodu içeren görselin adını girin (kapak görsel): ")
    gizli_qr_dosya = "cikarilan_qr.png"
    qr_dosya = input("QR kod dosya adını girin: ")
    okul_no = input("Okul numaranızı girin: ").strip()

    with open("student_ids.json", "r") as f:
        student_map = {k.strip(): v.strip() for k, v in json.load(f).items()}

    school_name = student_map.get(okul_no)
    if not school_name:
        print("Bu öğrenci numarasına ait kayıt bulunamadı.")
        exit()

    key = derive_key_from_school_name(school_name)

    if not extract_qr_from_image(kapak_dosya, gizli_qr_dosya):
        print("Gizli QR çıkarılamadı.")
        exit()

    qr_data = read_qr(gizli_qr_dosya)
    if qr_data:
        result = decrypt_message(qr_data, key)
        if result:
            print(f"Mesaj başarıyla çözüldü: {result}")
        else:
            print("Mesaj çözülemedi. Okul numarası veya veri hatalı olabilir.")
    else:
        print("QR koddan veri alınamadı.")
