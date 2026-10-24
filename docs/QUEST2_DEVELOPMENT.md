# Quest 2 geliştirme sürümü

## Düzeltilen hata: sonuç ekranından menüye dönüş (25 Ekim 2026)

Kullanıcı Main Menu sonrası uygulamanın kapandığını ve yeniden açılmadığını
bildirdi. Bağlı Quest 2 kayıtlarında native SIGSEGV doğrulandı. Son seçilen
harita ayarı geçici olarak kaldırıldığında eski APK açıldı. Cihazın gerçek
harita/skor verileriyle yerel tekrar üretim, HighscorePanel içindeki detached
satır kopyasının çocuklarını kaybettiğini gösterdi. Satırlar artık bağımsız
Label çocuklarıyla oluşturuluyor; temizlenen satırlar hemen listeden çıkarılıyor.
Orijinal ayar, şarkı ve skorlar korunarak düzeltme cihaza yüklendi. Soğuk açılış
OpenXR ve nesne havuzlarını tamamladı. Kullanıcı gözlükte kapanma sorununun
çözüldüğünü doğruladı.

Kod incelemesinde ayrı bir giriş durumu hatası düzeltildi: ekran değişimi iki
UI ışınının eski hedefini ve basılı fare durumunu temizler; eski ekranın tetik
bırakma olayı yeni ekrana iletilmez. UI alanından ayrılırken basış kontrolün
dışında iptal edilir. Yeni ekranda yeniden tıklamak için tetiğin bırakılması
beklenir. `SESSION_STATE` günlükleri son tamamlanan ekran geçişini gösterir.

12 ardışık sonuç/replay/menü/oynatma turu, giriş iptali ve diskten yüklenen
skor satırları dahil 280 headless kontrol geçti. Test kapanışında ObjectDB ve
iki kaynak için yaşam süresi uyarısı bulunuyor. Tam APK derlemesi ortamın Gradle
soket kısıtlamasında durdu. Bu nedenle mevcut APK'nın yalnız HighscorePanel
bytecode'u ve sparse paket indeksindeki boyut/MD5 kaydı güncellenip aynı geliştirme
anahtarıyla imzalandı. Diğer APK varlıklarının değişmediği doğrulandı. Kurulan
paket bekleyen giriş düzeltmelerini içermez. Varsayılan APK çıktısı da bu
paketle güncellendi; eski APK ve paket özeti `artifacts/menu-crash/` altında.

Bu dal, OpenSaberPlus'ın oyun altyapısını iyileştirir. Beat Saber ile görüntü,
kesme hissi veya performans eşitliği henüz doğrulanmış değildir.

## Kurulum ve komutlar

macOS, Python 3.9+, Android SDK platform 35 / build-tools 35.0.0 ve Android
ile uyumlu JDK 17 (veya 21) gerekir. JDK 17 otomatik seçilir; Android Studio
içindeki daha yeni JDK sürümleri otomatik kullanılmaz. Godot ve Android XR Vendors proje içine indirilir;
`tools/toolchain.lock.json` içindeki sürüm ve dosya özetleri doğrulanır.

```sh
python3 tools/quest.py bootstrap
python3 tools/quest.py test
python3 tools/quest.py build
python3 tools/quest.py install
python3 tools/quest.py collect
```

SDK/JDK farklı yerdeyse `--sdk /path/to/sdk --java /path/to/jdk` kullanın.
Birden fazla cihaz varsa `--serial DEVICE_SERIAL` verin. Kurulum komutu USB
hata ayıklama yetkisi verilmiş cihaz gerektirir ve uygulamayı başlatır.

APK çıktısı: `artifacts/OpenSaberPlus-Quest2-0.8.0-dev.apk`.
Paket adı: `org.godotengine.open_saber_plus.dev`.
Geliştirme imzası `.tools/debug.keystore` içinde üretilir; aynı anahtarı
koruyarak sonraki APK'ları verileri silmeden güncelleyebilirsiniz.
Bu anahtar, indirilen araçlar ve cihaz çıktıları git dışında tutulur.
Godot 4.6-stable / XR Vendors 4.3.1-stable / Gradle 8.11.1 sabitlenmiştir.
Gradle ZIP dosyası da SHA-256 ile doğrulanıp yerel kopyadan açılır. Android Gradle
bağımlılıkları ilk derlemede internet bağlantısı gerektirir.

## Uygulanan davranış

- Tek ses saati: miks zamanı ve çıkış gecikmesiyle düzeltilen ses konumu,
  NJS/jump offset kaynaklı görünme mesafesi, ±200 ms / 5 ms kalibrasyon.
  Pozitif kalibrasyon değeri notaları sese göre geciktirir.
- Yeniden başlatmada kaynak BPM değişmez. Duraklatma, nota hareketini ve
  bekleyen takip salınımı puanlarını durdurur; devamda üç saniye sayılır.
- Kesme puanı: 100° ön salınım için 70, 60° takip salınımı için 30,
  merkezden 0–15 cm uzaklık için 15 puan. Çarpanlar 1/2/4/8; sırasıyla
  2/4/8 başarılı vuruşta yükselir. Hatalı kesme bir kademe düşürür.
  Gecikmeli puanlama, vuruş anındaki çarpanı saklar.
- `standard115-v1` kayıtları eski skorlardan ayrı dosyaya yazılır.
  Harita içeriği ve oyun değiştiricileri skor anahtarına dahildir.
- Standart, sabit BPM v2/v3 haritalar desteklenir. v4, BPM değişimleri,
  rotasyon haritaları ve zorunlu modlar açık hata mesajıyla reddedilir.
  Arc/chain haritaları deneysel oynanabilir; rekor kaydetmez. Tam arc/chain
  davranış eşitliği bu sürümün kabul kriteri değildir.
- İndirme HTTP sonucunu, ZIP yollarını, metadata/difficulty dosyalarını ve
  ses dosyası varlığını kontrol eder. Tamamlanan geçici klasör Songs'a
  taşınır; başarısız indirme mevcut şarkıyı değiştirmez. Ses içeriğinin Ogg
  olarak çözülebildiği oynatma öncesinde ayrıca doğrulanır.
- Nota/chain havuzlarına ek olarak bomba, duvar ve arc havuzları; haritanın
  eşzamanlı nesne aralıklarına göre ön ayırma; çalışma anında büyüme sayacı.
- 72 Hz isteği, 2x MSAA, kapalı glow. Düşük profilde %85 render ölçeği ve
  azaltılmış dekorasyon. Bunlar performans ayarlarıdır, FPS garantisi değildir.
- Harita yükleme iş parçacıkları için ortak liste yarışı kaldırıldı. Kapak
  görseli callback'leri ana iş parçacığına taşındı ve işler join edilir.

## Doğrulama ve kalan işler

`test` komutu saf kuralları ve tam oyun sahnesinde başlatma, tekrar başlatma,
duraklatma, çift kesme/miss, son puanın tamamlanması, deneysel skor engeli,
havuzlara dönüş ve geçersiz haritada menüye dönüşü denetler. Sentetik test
haritası, mevcut repo sesini yalnızca yerel test için kullanır.

Bu ortamda 143 kontrol geçti. Sonuç ekranındaki animasyon artık ekran gizlenince
iptal edilir; yarıda kalan coroutine kaynaklı grafik kaynak sızıntısı giderildi.
Headless kapanışında aralıklı ObjectDB/kaynak uyarıları gözlendi; cihazdaki
bellek kararlılığı ayrıca doğrulanmalı. Menü kapanırken kapak görseli işçileri
artık beklenip kapatılır ve bekleyen arayüz callback’leri iptal edilir.

Gradle indirme/DNS engeli yerel ve doğrulanmış ZIP ile aşıldı. Ancak bu oturumun
sandbox'ı Gradle'ın yerel sunucu soketini açmasına izin vermiyor:
`java.net.SocketException: Operation not permitted`. JDK 17 ile `--no-daemon`
denemesinde de `ServerSocketChannelImpl.bind` aşamasında aynı hata doğrulandı.
APK henüz üretilmedi. Normal macOS Terminal'inde aşağıdaki komutla devam edin:

```sh
python3 /Users/selmanpoyraz/Desktop/maverick/elif/beatsaber/OpenSaberPlus/tools/quest.py build
```

Alternatif olarak `tools/BuildQuest.command` dosyasını Terminal'de çalıştırın.
İlk Android bağımlılık çözümlemesi internet gerektirir. Ayrıntılı hata kaydı
`artifacts/build.log`, soket tanı kaydı `artifacts/gradle-diagnostic.log` içindedir.
Üretilmiş `android/build` klasörü Godot taramasından ve APK kaynak seçiminden
hariç tutulur; böylece ikinci export önceki export'un dosyalarını paketlemez.

Quest 2 bağlı olmadığı için kontrolcü hissi, ses senkronizasyonu, görsel çıktı,
Android izinleri/indirme akışı ve uzun süreli performans cihazda denenmedi.
Yeni şarkı paketi veya ticari Beat Saber içeriği eklenmedi. BeatSaver canlı
ağ akışı ve hatalı/yarıda kesilen indirme senaryoları cihazda doğrulanmalı.

## Oyun oturumu iyileştirmeleri

- OpenXR görünürlük/odak kaybı ve uygulamanın arka plana geçmesi oyunu duraklatır.
  Odak geri geldiğinde oyuncu devam düğmesine basar; otomatik devam edilmez.
- Üç saniyelik devam sayacı iptal edilebilir. Odak kaybı, menüye çıkış veya
  restart sonrasında eski bir sayaç oyunu tekrar başlatamaz.
- Yükleme sırasında menüye çıkılırsa bekleyen başlangıç iptal edilir. Odak
  yokken tamamlanan yükleme duraklatılmış durumda kalır.
- Tekrarlanan pause bildirimleri animasyon hızını sıfıra kilitlemez. Halka
  dönüş tween'leri de duraklatılır; restart eski ışık/halka hareketlerini ve
  lazer animasyonu konumunu sıfırlar.
- Üst üste gelen duvarlar ayrı izlenir. Son duvardan çıkana kadar etki devam
  eder; duraklatılmış oyunda duvara giriş combo/sağlık cezası vermez.
- Ses dosyası erken biterse son harita nesnesinin geçişi ve takip salınımı
  tamamlanmadan sonuç ekranına geçilmez.

Bu davranışlar tam oyun sahnesinde sentetik odak ve zaman ilerletmeleriyle
kontrol edildi. Gerçek OpenXR runtime olay sırası cihaz testine dahildir.

## Şarkı kütüphanesi iyileştirmeleri

- Seçilen zorluk oynatılmadan doğrulanır. Eksik ses, bozuk/uyumsuz harita ve
  zorunlu mod nedenleri menüde görünür; Oyna düğmesi devre dışı kalır.
  Arc/chain haritaları deneysel ve rekorsuz olarak etiketlenir.
- Doğrulama sonucu aynı seçimde yeniden kullanılır; Oyna düğmesinde dosya tekrar
  kontrol edilerek dışarıdan değişmiş bir haritanın eski sonuçla başlaması önlenir.
- Son oynanan zorluk, favori bayrağından ayrı okunur ve rank değeri doğru liste
  indeksine çevrilir. Zorluksuz metadata ve boş filtre sonucu güvenli gösterilir.
- Kapak işçileri ikiyle sınırlıdır. Liste kapakları en fazla 128, seçili kapak
  en fazla 512 piksel olacak şekilde oranı korunarak küçültülür. 64 girdilik LRU
  önbellek dosya zamanı ve görsel boyutu bazında yeniden kullanılır.
- Liste veya şarkı değiştiğinde eski kapak callback'leri yeni seçimi değiştiremez;
  henüz başlamamış kapak işleri yeni listeye geçerken iptal edilir.
- Yeni şarkı önizlemesi eski fade-out'u iptal eder. Önizleme süresi oynatma hızına
  göre hesaplanır; ana oyun saati başladığında önizleme durdurulur.
- Kuyruktaki indirmeler liste yenilense de tekrar eklenemez. Başarısız indirme
  yeniden denenebilir olur ve hata görünür kalır. İndirme/önizleme isteklerinde
  zaman aşımı vardır; HTTP hata gövdesi ses olarak oynatılmaz.

117 kontrolün içinde menü durumları, eski kapak callback'leri, önbellek boyutları,
önizleme değişimi ve sentetik indirme hata yanıtları yer alır. Canlı BeatSaver
bağlantısı ve gerçek büyük kütüphanede cihaz performansı henüz ölçülmedi.

## Kesme hissi ve kare süresi

- Vuruş sesi temas anında başlar. Eski kodun erken kesmelerde nota zamanına
  kadar uyguladığı 200 ms'ye varan yazılımsal bekleme ve geç kesmelerde sesin
  başlangıcını atlaması kaldırıldı. Fiziksel ses gecikmesi cihazda ölçülmelidir.
- Vuruş titreşimi 100 ms yerine 45 ms sürer; kuvveti korunur. Boşta sıfır
  şiddetli titreşim komutu gönderilmez. Bu ayarın hissi gözlükte denenmelidir.
- Fizik sırası açık: ses saati, kontrolcü, notalar, kılıç örnekleme, kesme
  sorguları. Ana ışın önceki otomatik sorgu yerine mevcut pozisyonla sorgulanır.
- Otomatik ışın sorguları kapalıdır. Varsayılan sekiz segmentle her kılıç için
  bir fizik adımında 1–9 manuel kesme sorgusu; pause sırasında 0 sorgu vardır.
  Zemin efekti ışını bu sayıya dahil değildir ve ayrıca tek manuel sorgu yapar.
- Aynı nesneye ait çoklu segment çarpışmaları tek olaya indirgenir. Küçük
  hareketler için eski 3.5 cm eşiği 1 mm'ye indirilir. Tekrarlanan collider
  sorgularını azaltmak için doğruluktan vazgeçilmez; hızlı savuruş testi vardır.
- Kesme düzlemi nota hareketini BPM, NJS ve şarkı hızına göre hesaba katar;
  sabit kılıçta sıfır normal üretmez. Önceki iki kat hareket hesabı düzeltildi.
- Salınım geçmişi, her fizik adımında dizi üretip kaydırmak yerine 256 örneklik
  sabit belleği yeniden kullanır. 200 ms ön/son salınım pencereleri korunur.
- HUD gerçek skor değişiminde güncellenir; zaman göstergesi 10 Hz, debug bilgisi
  4 Hz yenilenir. Her fizik adımında sahte skor-değişti sinyali yayınlanmaz.
- Kılıç izi mesh'i sahne köküne bırakılmaz; kendi kılıcıyla birlikte temizlenir.
  Tracking reset sırasında eski iz geometrisi de temizlenir.
- CSV'ye fizik işlem süresi, iki kılıcın kesme sorgu süresi ve sorgu sayısı
  eklendi. Bunlar son fizik adımının render karelerindeki örnekleridir; bir
  karedeki tüm fizik adımlarının toplamı değildir. JSON p99 özetleri de eklenir.

137 kontrolün içinde fizik dünyasında hızlı savuruş, tekil çarpışma bildirimi,
sorgu bütçesi, geçmiş belleğinin çevrimi, kesme düzlemi, anlık ses ve HUD sinyal
kontrolleri vardır. Headless testler GPU performansı veya gerçek kontrolcü hissi
ölçümü değildir; FPS artışı ve 72 Hz kabulü henüz doğrulanmadı.

## Görsel netlik ve ritim oyunu görünümü

- Bevel'li mevcut blok mesh'i korunur. 256 px atlasın ok/dot işaretleri yerine
  nesne koordinatlarında çizilen, türev tabanlı kenar yumuşatmalı işaretler
  kullanılır. Oklar yalnızca ön yüzde görünür; kesilmiş parçalar aynı shader'ı
  kullanır. Yeni yüksek poligon yükü eklenmez.
- Bloklar daha koyu gövde, belirgin bevel ve beyaz yön işaretiyle ayrılır.
  Kılıçlarda bloom'a bağımlı olmayan beyaz çekirdek/renkli kenar kullanılır.
- Duvarların yoğun hareketli gürültüsü yerine ince ızgara ve parlak sınırlar
  kullanılır. Saydam duvarların GPU overdraw maliyeti cihazda ölçülmelidir.
- Bombaların koyu metal gövdesi ve ince tehlike sınırı korunur; kalın dış
  büyütme azaltılır. Çarpışma şekilleri ve oyun ölçüleri değiştirilmez.
- Yeni kurulumlarda kırmızı sol/mavi sağ palet ve koyu arena arka planı gelir.
  Mevcut ayarlarla aynı görünümü seçmek için ayarlarda
  `Classic rhythm look: red / blue + dark arena` düğmesi vardır.
- Standard: 2x MSAA / %100 render; Low: 2x / %85; Clarity: 4x / %110.
  Clarity daha yüksek GPU maliyetlidir ve 72 Hz garantisi vermez. Shader
  işaretleri her profilde aynıdır; kalite uğruna oyun çarpışmaları değişmez.

`tools/visual_preview.tscn` gerçek oyun materyallerini gösteren bağımsız bir
kontrol sahnesidir. Godot editöründen açılıp F6 ile çalıştırılabilir. Bu ortamda
pencereli önizleme macOS `_RegisterApplication` / `NSApplication` başlatma
adımında SIGABRT ile durduğu için gerçek görüntü alınamadı. Pencereli başlatma
tekrarlanmadı. 143 headless kontrol, materyal kaynakları, shader uniformları,
bağımsız duvar materyalleri ve kalite profilleri dahil geçiyor; bunlar GPU
shader çalışması veya Beat Saber ile görsel eşitlik doğrulaması değildir.

## Hata günlüklerinin ayrımı

- Son GUI çökmesi oyun sahnesinden önce macOS uygulama kaydında oluştu.
- 11 eski kaynak UID referansı gerçek UID'lerle eşlendi; `Info.dat` seçimi
  diskteki harf biçimini koruyacak şekilde düzeltildi.
- Sandbox içindeki Godot kullanıcı klasörü ve sistem sertifika erişimi
  başlangıç mesajları sürüyor; uygulamanın test verisi proje içinde tutuluyor.
- Eksik ses / desteklenmeyen harita / başarısız indirme uyarılarının bir kısmı
  otomatik testlerin bilerek tetiklediği durumlar.
- Aralıklı ObjectDB/kaynak kapanış uyarısı ayrıca takip ediliyor. Verbose
  çalışmada aynı uyarının görünmemesi çözüldüğünün kanıtı sayılmıyor.

## Cihaz kabul turu

1. APK'yı derleyip kurun; varsayılan profilde 72 Hz'i cihaz profiler'ıyla doğrulayın.
2. Seyrek ve yoğun v2/v3 haritalarda her el, yönlü/dot nota, bomba, duvar,
   son nota, pause/resume ve arka arkaya restart senaryolarını oynayın.
3. Kalibrasyon sınırlarını ve %100 dışındaki müzik hızlarını deneyin.
4. Deneysel arc/chain haritasının rekor yazmadığını, desteklenmeyen haritanın
   oynatılmadığını ve ağ kesintisinin yarım şarkı bırakmadığını doğrulayın.
5. En az 30 dakika oynayın; her iki kalite profilini, bellek büyümesini ve
   uygulama odağı kaybı/geri dönüşünü ölçün.

Uygulama `files/metrics` altında CSV ve p99 JSON üretir. `collect` bunları
`artifacts/device-metrics` içine çeker. Render CPU süresi tüm oyun CPU süresi
değildir; sıfır GPU ölçümü desteklenmeyen sayaç anlamına gelebilir. Gerçek
düşen kare sayısı ve CPU/GPU kabulü için Quest runtime profiler verisi gerekir.
Hedef: 72 Hz, p99 CPU/GPU ≤13.89 ms ve 30 dakika boyunca <%1 düşen kare.
Bu şartlar ölçülmeden performans kabulü tamamlanmış sayılmaz.

## Puan efektleri ve VR klavye (25 Ekim 2026)

Kesme puanları artık konturlu, kalın ve yatık Label3D yazılarıdır. Yüksek
kesmeler turkuaz, diğer puanlar buz beyazı, hatalar kırmızı × ile gösterilir.
0.10 saniyelik büyüme, kısa yerleşme ve son yarıda saydamlaşmayla 0.85 saniyede
kaybolurlar. 24 öğeli havuz kullanılır; kaçırma yazıları oyuncunun önüne alınır.
Combo HUD'u yatık yazı ve kısa ölçek vurgusu kullanır; her 25 comboda altın
renkli bildirim çıkar. Klavyede koyu tuşlar, turkuaz hover/pressed durumları,
düz silme/onay/kapatma tuşları ve eşleşen metin alanı bulunur.

`tests/feedback_checks.tscn` 78 kontrolle tuş sınırlarını, shift/sembol/silme/
boşluk eşlemesini, efekt havuzunu, kaçırma konumunu ve yeniden kullanımda
saydamlığın sıfırlanmasını doğrular. Genel testlerde 280 kontrol geçer.
Paket, doğrulanmış menü düzeltmesinin üzerine dört betik ve sparse indeks
kaydı güncellenerek hazırlanır; şarkı/skor verileri korunur.
