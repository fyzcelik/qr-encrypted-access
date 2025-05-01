# import cv2
# import hashlib
# import base64
# import json
# from cryptography.hazmat.primitives.ciphers.aead import AESGCM
# from fastapi import FastAPI, UploadFile, Form
# from fastapi.responses import PlainTextResponse

# app = FastAPI()

# def extract_qr_from_image(cover_image_path, output_qr_path):
#     cover_img = cv2.imread(cover_image_path)
#     if cover_img is None:
#         print("[!] Görsel yüklenemedi.")
#         return False

#     # Gizlenmiş QR kod LSB yöntemine göre kırmızı kanalın en düşük bitine saklanmış varsayılıyor
#     height, width, _ = cover_img.shape
#     qr_img = cv2.cvtColor(cover_img, cv2.COLOR_BGR2GRAY)

#     for y in range(height):
#         for x in range(width):
#             lsb = cover_img[y, x, 2] & 1  # kırmızı kanal
#             qr_img[y, x] = 255 if lsb else 0

#     cv2.imwrite(output_qr_path, qr_img)
#     return True

# def decrypt_message(encrypted_json):
#     try:
#         data = json.loads(encrypted_json)
#         nonce = base64.b64decode(data['nonce'])
#         ciphertext = base64.b64decode(data['cipher'])
#         key = base64.b64decode(data['key'])  # Artık key direkt veri içinde geliyor

#         aesgcm = AESGCM(key)
#         decrypted = aesgcm.decrypt(nonce, ciphertext, None)
#         return decrypted.decode()
#     except Exception as e:
#         print(f"[!] Şifre çözme hatası: {e}")
#         return None

# def read_qr(filename):
#     img = cv2.imread(filename)
#     detector = cv2.QRCodeDetector()
#     data, bbox, _ = detector.detectAndDecode(img)
#     return data if data else None

# @app.post("/decode")
# async def decode_qr(image: UploadFile = None):
#     contents = await image.read()
#     temp_path = "uploaded_hidden.png"
#     with open(temp_path, "wb") as f:
#         f.write(contents)

#     qr_path = "extracted_qr.png"
#     if not extract_qr_from_image(temp_path, qr_path):
#         return PlainTextResponse("Gizli QR çıkarılamadı.", status_code=400)

#     qr_data = read_qr(qr_path)
#     if not qr_data:
#         return PlainTextResponse("QR koddan veri alınamadı.", status_code=400)

#     result = decrypt_message(qr_data)
#     if not result:
#         return PlainTextResponse("Mesaj çözülemedi. Veri hatalı olabilir.", status_code=400)

#     return PlainTextResponse(result, status_code=200)
