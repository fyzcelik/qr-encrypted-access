from fastapi import FastAPI, UploadFile, Form, HTTPException
from fastapi.responses import StreamingResponse, FileResponse
from io import BytesIO
import qrcode
from PIL import Image
import os
import cv2
import numpy as np

app = FastAPI()

# QR Kodu Oluşturma
def qr_olustur(mesaj: str, qr_dosya: str = "gizli_qr.png") -> str:
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
def qr_gizle(qr_yolu: str, kapak_yolu: str, cikti_yolu: str = "gizli_resim.png") -> str:
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
def qr_cikar(gizli_resim_yolu: str, cikti_qr_yolu: str = "cikarilan_qr.png") -> str:
    try:
        # OpenCV ile resmi yükle
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

# QR Okuma
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

# FastAPI Endpoint'leri
@app.post("/qr_gizle")
async def qr_gizle_api(
    mesaj: str = Form(...),
    resim: UploadFile = UploadFile(...)
):
    try:
        # Geçici dosyalar
        temp_kapak = "temp_kapak.png"
        qr_yolu = "temp_qr.png"
        cikti_yolu = "gizli_resim.png"
        
        # QR oluştur
        qr_olustur(mesaj, qr_yolu)
        
        # Yüklenen resmi kaydet
        with open(temp_kapak, "wb") as f:
            f.write(await resim.read())
        
        # QR'ı resme gizle
        qr_gizle(qr_yolu, temp_kapak, cikti_yolu)
        
        # Temizlik
        os.remove(temp_kapak)
        os.remove(qr_yolu)
        
        return FileResponse(cikti_yolu, media_type="image/png")
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/qr_cikar")
async def qr_cikar_api(resim: UploadFile = UploadFile(...)):
    try:
        # Geçici dosyalar
        temp_gizli = "temp_gizli.png"
        cikti_qr = "cikarilan_qr.png"
        
        # Yüklenen resmi kaydet
        with open(temp_gizli, "wb") as f:
            f.write(await resim.read())
        
        # QR çıkar
        qr_cikar(temp_gizli, cikti_qr)
        
        # QR'ı oku
        mesaj = qr_oku(cikti_qr)
        
        # Temizlik
        os.remove(temp_gizli)
        
        return {
            "mesaj": mesaj,
            "qr_kodu": FileResponse(cikti_qr, media_type="image/png")
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Konsol Kullanımı
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)