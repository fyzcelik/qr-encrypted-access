import cv2
import qrcode
import numpy as np
from PIL import Image
from skimage.metrics import peak_signal_noise_ratio as psnr
from skimage.metrics import mean_squared_error as mse
from tabulate import tabulate


def generate_qr(message, filename):
    qr = qrcode.make(message)
    qr.save(filename)
    print(f"✅ QR kod '{filename}' dosyasına kaydedildi.")


def embed(container_path, qr_path, output_path, method):
    container = Image.open(container_path).convert("RGBA")
    container_arr = np.array(container)

    qr = Image.open(qr_path).convert('L').resize((100, 100))
    qr_arr = np.array(qr)
    qr_bits = (qr_arr > 128).astype(np.uint8)

    region = container_arr[:100, :100].copy()

    if method == 'lsb-red':
        region[:, :, 0] = (region[:, :, 0] & ~1) | qr_bits
    elif method == 'lsb-multichannel':
        region[:, :, 1] = (region[:, :, 1] & ~1) | qr_bits
        region[:, :, 2] = (region[:, :, 2] & ~1) | qr_bits
    elif method == 'alpha-channel':
        region[:, :, 3] = (region[:, :, 3] & ~1) | qr_bits
    else:
        raise ValueError("❌ Geçersiz gömme yöntemi")

    container_arr[:100, :100] = region
    stego_img = Image.fromarray(container_arr)
    stego_img.save(output_path)
    print(f"📦 {method} yöntemiyle QR kod '{output_path}' görseline gömüldü.")


def extract_qr(stego_path, output_path, method):
    stego = Image.open(stego_path).convert("RGBA")
    arr = np.array(stego)
    region = arr[:100, :100]

    if method == 'lsb-red':
        qr_bits = region[:, :, 0] & 1
    elif method == 'lsb-multichannel':
        qr_bits = ((region[:, :, 1] & 1) + (region[:, :, 2] & 1)) // 2
    elif method == 'alpha-channel':
        qr_bits = region[:, :, 3] & 1
    else:
        raise ValueError("❌ Geçersiz çözümleme yöntemi")

    qr_arr = (qr_bits * 255).astype(np.uint8)
    qr_img = Image.fromarray(qr_arr, mode='L')
    qr_img.save(output_path)
    print(f"🔍 {method} yöntemiyle QR çıkarıldı: {output_path}")


def compare_images(original_path, stego_path):
    orig = np.array(Image.open(original_path).convert("RGB"))
    stego = np.array(Image.open(stego_path).convert("RGB"))
    mse_val = mse(orig, stego)

    if mse_val == 0:
        psnr_val = float('inf')
    else:
        psnr_val = psnr(orig, stego)

    return psnr_val, mse_val


def decode_qr(image_path):
    img = cv2.imread(image_path)
    detector = cv2.QRCodeDetector()
    data, _, _ = detector.detectAndDecode(img)
    return data if data else None


def main():
    try:
        message = input("📥 Lütfen QR koduna gömülecek mesajı girin: ")
        qr_filename = "qr_kod.png"
        generate_qr(message, qr_filename)

        container_path = input("📁 Kaplayıcı (container) görsel dosya yolunu girin (örn: container.png): ")

        methods = ['lsb-red', 'lsb-multichannel', 'alpha-channel']
        results = []

        for method in methods:
            print(f"\n🔧 {method.upper()} yöntemiyle işleniyor...")
            stego_filename = f"gizlenmiş_qr_{method}.png"
            extracted_qr = f"çözülmüş_qr_{method}.png"

            embed(container_path, qr_filename, stego_filename, method)
            extract_qr(stego_filename, extracted_qr, method)

            qr_text = decode_qr(extracted_qr)
            match = qr_text == message
            psnr_val, mse_val = compare_images(container_path, stego_filename)
            psnr_str = f"{psnr_val:.2f}" if psnr_val != float('inf') else "∞"

            results.append({
                "Yöntem": method,
                "PSNR (dB)": psnr_str,
                "MSE": f"{mse_val:.2f}",
                "QR Doğruluğu": "✅" if match else "❌",
                "Çözülen Mesaj": qr_text if qr_text else "Yok"
            })

        print("\n📊 Karşılaştırma Tablosu:")
        print(tabulate(results, headers="keys", tablefmt="fancy_grid"))

    except Exception as e:
        print(f"❌ Hata oluştu: {str(e)}")


if __name__ == "__main__":
    main()
