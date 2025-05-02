import qrcode
import numpy as np
from PIL import Image
import os

def generate_qr(message, filename):
    """
    Verilen mesajı QR koda çevirir ve filename adıyla kaydeder.
    """
    try:
        qr = qrcode.make(message)
        qr.save(filename)
        print(f"QR kod '{filename}' dosyasına kaydedildi.")
    except Exception as e:
        print(f"QR kodu oluşturulurken hata: {str(e)}")
        raise RuntimeError(f"QR kodu oluşturulamadı: {str(e)}")

def embed_qr_into_image(container_path, qr_path, output_path):
    """
    Verilen container (kaplayıcı) resim üzerine QR kodu gizler.
    Burada, QR kod sol üst köşeye, resmin kırmızı kanalının LSB'sine yerleştirilir.
    """
    try:
        # Kaplayıcı resmi aç ve RGB formatına çevir
        container = Image.open(container_path).convert("RGB")
        container_arr = np.array(container)
        
        # QR kodunu aç: burada "L" moduna çevirip eşikleme uygulaması yaptık
        qr = Image.open(qr_path).convert('L')
        
        # QR kod boyutunu uyumlu hale getirelim (container boyutuna göre)
        qr = qr.resize((100, 100))  # Sabit boyut, ama ihtiyaca göre değiştirebilirsiniz.
        qr_arr = np.array(qr)
        
        # Manuel eşikleme: 128 altındaki değerleri 0, üzerindekileri 1 yapalım
        qr_bits = (qr_arr > 128).astype(np.uint8)
        
        # Container'ın sol üst 100x100 bölgesini seçelim
        region = container_arr[:100, :100, :]
        
        # Kırmızı kanalın (ilk kanal) LSB'sini, qr_bits ile değiştirelim
        region[:, :, 0] = (region[:, :, 0] & ~1) | qr_bits
        container_arr[:100, :100, :] = region
        
        # Güncellenmiş resmi oluşturup kaydedelim
        stego = Image.fromarray(container_arr)
        stego.save(output_path)
        print(f"QR kod gizlenmiş resim '{output_path}' olarak kaydedildi.")
    except Exception as e:
        print(f"QR gizleme hatası: {str(e)}")
        raise RuntimeError(f"QR kodu görsele gizlenemedi: {str(e)}")
def extract_qr_from_image(stego_path, output_qr_path):
    """
    Gizlenmiş resmin (stego) sol üst köşesinden (100x100 bölge) QR kodu çıkarır.
    """
    try:
        stego = Image.open(stego_path).convert("RGB")
        arr = np.array(stego)
        
        # Gömülü bölgeyi alalım
        region = arr[:100, :100, :]
        
        # Kırmızı kanalın LSB'sini çıkaralım
        qr_bits = region[:, :, 0] & 1  # 0 veya 1 değerleri elde edilir.
        
        # Bit değerlerini 0 veya 255 ölçeğine getirelim
        qr_arr = (qr_bits * 255).astype(np.uint8)
        
        # QR kodunu oluşturup kaydedelim
        qr_img = Image.fromarray(qr_arr, mode="L")
        
        # Dinamik eşikleme ve iyileştirme yapılabilir
        qr_img.save(output_qr_path)
        print(f"Çözülmüş QR kod '{output_qr_path}' dosyasına kaydedildi.")
    except Exception as e:
        print(f"QR çıkarma hatası: {str(e)}")
        raise RuntimeError(f"QR çıkarılamadı: {str(e)}")

def main():
    try:
        # 1. Adım: Mesajı al ve QR koda dönüştür
        message = input("Lütfen bir mesaj girin: ")
        qr_filename = "qr_kod.png"
        generate_qr(message, qr_filename)
        
        # 2. Adım: Kaplayıcı resim yolunu al
        container_path = input("QR kodu saklamak için bir resim dosyası yolu girin (örn. container.jpg): ")
        stego_filename = "gizlenmis_resim.png"
        embed_qr_into_image(container_path, qr_filename, stego_filename)
        
        # 3. Adım: Çözümleme için bekle
        input("Gizlenmiş resmi çıkarmak için Enter'a basın...")
        extracted_qr_filename = "cozulmus_qr.png"
        extract_qr_from_image(stego_filename, extracted_qr_filename)
        
        print("İşlem tamamlandı. Çözülmüş QR kod görüntüsünü kontrol edebilirsiniz.")
    except Exception as e:
        print(f"Main işlevinde hata oluştu: {str(e)}")

if __name__ == "__main__":
    main()