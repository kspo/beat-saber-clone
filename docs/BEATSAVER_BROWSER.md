# Gözlük içinde BeatSaver

Ana menüde **DISCOVER SONGS** düğmesini seçin. **Search song or artist**
düğmesi gözlük klavyesini açar; örneğin `levitating` yazıp Enter'a basın.
Sonuçlarda şarkı/sanatçı, kapak, harita yapımcısı, süre, BPM, oy oranı ve
zorluklar gösterilir. **Listen** kısa önizlemeyi oynatır.

**DOWNLOAD** seçili haritayı gözlüğe indirir. İlerleme ve kuyruk ekranda
görünür; **Cancel** mevcut indirmeyi ve kuyruğu iptal eder. Başarısız indirme
tekrar denenebilir. Tamamlanınca **OPEN IN LIBRARY** ile şarkı otomatik seçilir;
zorluk seçip **PLAY** ile başlayın. İndirme sonrasında internet gerekmez.
Bu özellik için uygulama bir kez güncellenmelidir; sonraki şarkılarda PC veya
elle dosya kopyalama gerekmez.

## Uygulama

- API kaynağı: https://api.beatsaver.com/docs/swagger.json (25 Ekim 2026).
  `/search/text/{page}` için `q`, `order`, `pageSize`, `automapper`;
  harita yapımcısı için `/maps/uploader/{id}/{page}` kullanılır.
- Sonuçlar 20'şer alınır; **More results** ile devam edilir. Sıralama
  Relevance/Rating/Latest; önceki aramaya geri dönüş ve hata için Retry vardır.
- Yalnızca Published sürüm seçilir; taslak/bozuk yanıtlar atlanır. Kapaklar
  256 piksele küçültülür. Arama, kapak, önizleme ve indirme callback'leri
  iptal edilen/eski isteklerden korunur.
- ZIP önce geçici klasöre açılır; dosya yolları, metadata, sesin varlığı,
  zorluk dosyaları ve en az bir desteklenen zorluk doğrulanır. Sonra Songs'a
  taşınır. Önceki tam harita ezilmez, hatalı/geçici indirme temizlenir.
- Standart sabit BPM v2/v3 desteği korunur. Desteklenmeyen format/modlara
  sahip haritalar açıklamayla reddedilir. Arc/chain deneysel ve rekorsuzdur.
  Ogg ses çözümlemesi ve seçilen zorluk oynatma öncesi tekrar doğrulanır.
- Ağ indirmesi kuyrukla devam edebilir; yeni dosyalar otomatik kütüphaneye
  alınır. Arka plandaki yenileme oyun/keşif ekranına skor paneli açmaz.
- Ana giriş ve eski yan panel girişi aynı öndeki tarayıcıya gider; kütüphane
  gizlenir. Klavye öne taşınır, çıkışta gizlenir ve önizleme iptal edilir.

## Doğrulama

Sentetik API yanıtları ve yerel geçerli Ogg/harita ZIP'i ile uçtan uca indirme,
kurulum, kütüphanede seçim ve oyuna başlama test edilir. Ayrıca bozuk JSON,
HTTP 429, eski callback, iptal, yinelenen indirme, desteklenmeyen harita ve
VR hedeflerinin sınırları/çakışmaları kontrol edilir.

Canlı API isteği bu ortamda DNS erişimi nedeniyle doğrulanamadı. Gerçek
Quest ağ bağlantısı, klavye kullanımı ve görünüm cihazda kontrol edilmeli.
APK derleme denemesi Gradle'ın yerel soket açmasına izin verilmediği için
`java.net.SocketException: Operation not permitted` ile durdu. Mevcut APK
eski sürümdür; bu değişiklikleri içermez. Normal macOS Terminal'inde
`python3 tools/quest.py build` ve bağlı gözlük için `python3 tools/quest.py install`
komutları kullanılır.
