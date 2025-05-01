from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from io import BytesIO
import qrcode
from PIL import Image
import os
import cv2
import numpy as np

app = FastAPI()

# QR Kodu Oluşturma
def qr_olustur(mesaj: str, qr_dosya: str = "temp_qr.png") -> str:
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(mesaj)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    img.save(qr_dosya)
    return qr_dosya

# QR'ı Görsele Gizleme
def qr_gizle(qr_yolu: str, kapak_yolu: str, cikti_yolu: str = "output.png") -> str:
    qr_img = Image.open(qr_yolu).convert("1")  # Siyah-beyaz yap
    kapak_img = Image.open(kapak_yolu).convert("RGB")

    # QR boyutunu kapak resmiyle aynı yap
    qr_img = qr_img.resize(kapak_img.size)
    
    qr_piksel = qr_img.load()
    kapak_piksel = kapak_img.load()

    for y in range(kapak_img.height):
        for x in range(kapak_img.width):
            r, g, b = kapak_piksel[x, y]
            # Siyah piksel (0) için LSB'yi 0 yap, beyaz (1) için 1 yap
            bit = 0 if qr_piksel[x, y] == 0 else 1
            r = (r & ~1) | bit  # Kırmızı kanalın son bitini değiştir
            kapak_piksel[x, y] = (r, g, b)

    kapak_img.save(cikti_yolu)
    return cikti_yolu

# Görselden QR Çıkarma
def qr_cikar(gizli_resim_yolu: str, cikti_qr_yolu: str = "extracted_qr.png") -> str:
    try:
        img = cv2.imread(gizli_resim_yolu)
        if img is None:
            raise ValueError("Görsel yüklenemedi")
        
        height, width, _ = img.shape
        qr_img = np.zeros((height, width), dtype=np.uint8)

        # Kırmızı kanaldaki LSB'leri oku
        for y in range(height):
            for x in range(width):
                lsb = img[y, x, 2] & 1  # BGR formatında 2. kanal kırmızı
                qr_img[y, x] = 0 if lsb == 0 else 255  # Siyah-beyaz tersleme

        # Gürültüyü azaltmak için threshold uygula
        _, qr_img = cv2.threshold(qr_img, 127, 255, cv2.THRESH_BINARY)
        cv2.imwrite(cikti_qr_yolu, qr_img)
        return cikti_qr_yolu
    except Exception as e:
        raise RuntimeError(f"QR çıkarma hatası: {str(e)}")

# QR'dan Mesaj Okuma
def qr_oku(qr_yolu: str) -> str:
    try:
        img = cv2.imread(qr_yolu)
        detector = cv2.QRCodeDetector()
        data, _, _ = detector.detectAndDecode(img)
        if not data:
            raise ValueError("QR kodu okunamadı")
        return data
    except Exception as e:
        raise RuntimeError(f"QR okuma hatası: {str(e)}")

# Endpoint'ler
@app.post("/encode")
async def encode_message(
    message: str = Form(...),
    image: UploadFile = File(...)
):
    try:
        # Geçici dosyalar
        temp_qr = "temp_qr.png"
        temp_cover = "temp_cover.png"
        output_path = "output.png"
        
        # QR oluştur
        qr_olustur(message, temp_qr)
        
        # Yüklenen resmi kaydet
        with open(temp_cover, "wb") as f:
            f.write(await image.read())
        
        # QR'ı resme gizle
        qr_gizle(temp_qr, temp_cover, output_path)
        
        # Temizlik
        os.remove(temp_qr)
        os.remove(temp_cover)
        
        # Sonucu gönder
        with open(output_path, "rb") as f:
            return StreamingResponse(BytesIO(f.read()), media_type="image/png")
    
    except Exception as e:
        return {"error": str(e)}

@app.post("/decode")
async def decode_message(image: UploadFile = File(...)):
    try:
        # Geçici dosyalar
        temp_img = "temp_img.png"
        extracted_qr = "extracted_qr.png"
        
        # Yüklenen resmi kaydet
        with open(temp_img, "wb") as f:
            f.write(await image.read())
        
        # QR çıkar
        qr_cikar(temp_img, extracted_qr)
        
        # QR'dan mesajı oku
        message = qr_oku(extracted_qr)
        
        # Temizlik
        os.remove(temp_img)
        os.remove(extracted_qr)
        
        return {"message": message}
    
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)