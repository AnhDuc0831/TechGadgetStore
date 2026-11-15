-- =====================================================================
-- TECH GADGET STORE - FULL SEED DATA SCRIPT
-- Bổ sung đầy đủ Danh mục, Thương hiệu, Sản phẩm, Phiên bản (Variants),
-- Thông số kỹ thuật (Specifications), Hình ảnh đa dạng và Đánh giá (Reviews).
-- 
-- Tính năng:
-- - Tự động bổ sung các cột mới (images, discount_price, specifications) nếu chưa có.
-- - Tương thích 100% với Supabase SQL Editor và PostgreSQL nội bộ.
-- - Idempotent (ON CONFLICT DO UPDATE): Có thể chạy nhiều lần mà không bị lỗi trùng lặp.
-- =====================================================================

-- 0. Đảm bảo cấu trúc cột mới cho bảng products đã sẵn sàng
ALTER TABLE public.products 
  ADD COLUMN IF NOT EXISTS images text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS discount_price numeric(14,2) NULL,
  ADD COLUMN IF NOT EXISTS specifications jsonb NOT NULL DEFAULT '{}'::jsonb;

-- 1. BỔ SUNG & CẬP NHẬT DANH MỤC (CATEGORIES)
INSERT INTO public.categories (name, slug, description, image_url) VALUES
  ('Điện thoại Thông minh', 'smartphones', 'Smartphone flagship, iPhone, Galaxy, Xiaomi cao cấp chính hãng', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=600&q=80'),
  ('Laptop & Máy tính',    'laptops',     'Laptop văn phòng mỏng nhẹ, Ultrabook, laptop Gaming cấu hình khủng', 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=600&q=80'),
  ('Máy tính bảng',         'tablets',     'iPad, Galaxy Tab phục vụ học tập, thiết kế đồ họa và giải trí',   'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=600&q=80'),
  ('Tai nghe & Âm thanh',   'audio',       'Tai nghe chống ồn chủ động ANC, tai nghe TWS, loa Bluetooth cao cấp', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=600&q=80'),
  ('Đồng hồ thông minh',   'smartwatches','Smartwatch theo dõi sức khỏe, thể thao chuyên nghiệp và định vị GPS', 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=600&q=80'),
  ('Bàn phím & Chuột',     'keyboards-mice','Bàn phím cơ Custom, chuột công thái học cho coder và văn phòng', 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=600&q=80'),
  ('Màn hình máy tính',     'monitors',    'Màn hình 2K, 4K đồ họa chuẩn màu, màn hình gaming OLED 120-175Hz', 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?auto=format&fit=crop&w=600&q=80'),
  ('Phụ kiện & Cáp sạc',   'accessories', 'Củ sạc nhanh GaN 65W-140W, pin sạc dự phòng, cáp sạc siêu bền', 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=600&q=80')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  image_url = EXCLUDED.image_url,
  updated_at = NOW();

-- 2. BỔ SUNG & CẬP NHẬT THƯƠNG HIỆU (BRANDS)
INSERT INTO public.brands (name, logo_url) VALUES
  ('Apple',     'https://upload.wikimedia.org/wikipedia/commons/f/fa/Apple_logo_black.svg'),
  ('Samsung',   'https://upload.wikimedia.org/wikipedia/commons/2/24/Samsung_Logo.svg'),
  ('Dell',      'https://upload.wikimedia.org/wikipedia/commons/4/48/Dell_Logo.svg'),
  ('ASUS',      'https://upload.wikimedia.org/wikipedia/commons/2/2e/ASUS_Logo.svg'),
  ('Sony',      'https://upload.wikimedia.org/wikipedia/commons/c/ca/Sony_logo.svg'),
  ('Xiaomi',    'https://upload.wikimedia.org/wikipedia/commons/a/ae/Xiaomi_logo_%282021-%29.svg'),
  ('Logitech',  'https://upload.wikimedia.org/wikipedia/commons/1/17/Logitech_logo.svg'),
  ('Keychron',  'https://www.keychron.com/cdn/shop/files/Keychron_Logo_black_small_300x.png'),
  ('Marshall',  'https://upload.wikimedia.org/wikipedia/commons/9/91/Marshall_Logo.svg'),
  ('Anker',     'https://upload.wikimedia.org/wikipedia/commons/d/de/Anker_logo.svg'),
  ('LG',        'https://upload.wikimedia.org/wikipedia/commons/b/bf/LG_logo_%282015%29.svg')
ON CONFLICT (name) DO UPDATE SET
  logo_url = EXCLUDED.logo_url,
  updated_at = NOW();

-- 3. BỔ SUNG & CẬP NHẬT SẢN PHẨM (PRODUCTS)
INSERT INTO public.products (category_id, brand_id, name, slug, description, thumbnail_url, images, base_price, discount_price, specifications, is_active)
SELECT 
  c.id, 
  b.id, 
  v.name, 
  v.slug, 
  v.description, 
  v.thumbnail_url, 
  v.images, 
  v.base_price, 
  v.discount_price, 
  v.specifications::jsonb, 
  true
FROM (VALUES
  -- 1. iPhone 15 Pro Max
  ('smartphones', 'Apple', 'iPhone 15 Pro Max', 'iphone-15-pro-max',
   'Flagship đỉnh cao từ Apple với khung viền Titanium siêu bền nhẹ, nút Action Button mới, vi xử lý Apple A17 Pro tiến trình 3nm mang lại hiệu năng đồ họa ấn tượng và cụm camera zoom quang học 5x.',
   'https://images.unsplash.com/photo-1695048133142-1a20484d2569?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1695048133142-1a20484d2569?auto=format&fit=crop&w=1200&q=80',
     'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?auto=format&fit=crop&w=1200&q=80'
   ],
   29990000, 28490000,
   '{"Màn hình": "6.7 inch Super Retina XDR OLED 120Hz ProMotion", "Vi xử lý": "Apple A17 Pro (3nm)", "RAM": "8GB", "Camera": "Chính 48MP + 12MP UltraWide + 12MP Tele 5x", "Pin & Sạc": "4422 mAh, Cổng sạc USB-C 3.0", "Hệ điều hành": "iOS 17"}'
  ),

  -- 2. Samsung Galaxy S24 Ultra
  ('smartphones', 'Samsung', 'Samsung Galaxy S24 Ultra 5G', 'samsung-galaxy-s24-ultra',
   'Kỷ nguyên quyền năng Galaxy AI với màn hình Dynamic AMOLED 2X 6.8 inch phẳng chống phản chiếu Corning Gorilla Armor, bút S-Pen tích hợp và camera 200MP zoom chuẩn mắt thần đêm.',
   'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?auto=format&fit=crop&w=1200&q=80'
   ],
   31990000, 27990000,
   '{"Màn hình": "6.8 inch Dynamic AMOLED 2X 120Hz chống chói", "Vi xử lý": "Snapdragon 8 Gen 3 for Galaxy", "RAM": "12GB", "Camera": "200MP + 50MP 5x + 10MP 3x + 12MP góc rộng", "Tính năng đặc biệt": "Tích hợp Galaxy AI & Bút S-Pen", "Pin & Sạc": "5000 mAh, Sạc siêu nhanh 45W"}'
  ),

  -- 3. iPhone 15
  ('smartphones', 'Apple', 'iPhone 15', 'iphone-15',
   'Apple iPhone 15 mang màn hình Dynamic Island tương tác linh hoạt, cụm camera chính 48MP sắc nét gấp 4 lần và cổng kết nối chuẩn USB-C tiện lợi.',
   'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?auto=format&fit=crop&w=1200&q=80'
   ],
   19990000, 18290000,
   '{"Màn hình": "6.1 inch Super Retina XDR OLED Dynamic Island", "Vi xử lý": "Apple A16 Bionic", "RAM": "6GB", "Camera": "Chính 48MP + Góc rộng 12MP", "Cổng sạc": "USB-C", "Hệ điều hành": "iOS 17"}'
  ),

  -- 4. Samsung Galaxy S24
  ('smartphones', 'Samsung', 'Samsung Galaxy S24', 'samsung-galaxy-s24',
   'Thiết kế nhỏ gọn vừa vặn bàn tay, màn hình Dynamic AMOLED 2X 6.2 inch viền siêu mỏng, hỗ trợ trọn bộ tính năng thông minh Galaxy AI và pin tối ưu vượt trội.',
   'https://images.unsplash.com/photo-1580910051074-3eb694886505?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1580910051074-3eb694886505?auto=format&fit=crop&w=1200&q=80'
   ],
   18990000, 16990000,
   '{"Màn hình": "6.2 inch FHD+ Dynamic AMOLED 2X 120Hz", "Vi xử lý": "Exynos 2400 10-nhân", "RAM": "8GB", "Camera": "50MP + 12MP + 10MP tele 3x", "Pin & Sạc": "4000 mAh, Sạc nhanh 25W"}'
  ),

  -- 5. Xiaomi 14 Ultra
  ('smartphones', 'Xiaomi', 'Xiaomi 14 Ultra 5G Leica', 'xiaomi-14-ultra',
   'Kiệt tác nhiếp ảnh di động đồng chế tác cùng Leica với cụm 4 ống kính quang học 50MP cảm biến 1-inch Sony LYT-900, khẩu độ biến thiên vô cấp f/1.63 - f/4.0.',
   'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=1200&q=80'
   ],
   29990000, 26490000,
   '{"Màn hình": "6.73 inch LTPO AMOLED WQHD+ 120Hz 3000 nits", "Vi xử lý": "Snapdragon 8 Gen 3", "RAM": "16GB LPDDR5X", "Ống kính": "Leica Vario-Summilux 4 camera 50MP", "Pin & Sạc": "5000 mAh, Sạc có dây 90W & Không dây 80W"}'
  ),

  -- 6. MacBook Pro 14 M3 Pro
  ('laptops', 'Apple', 'MacBook Pro 14 inch M3 Pro', 'macbook-pro-14-m3-pro',
   'Cỗ máy sáng tạo chuyên nghiệp với chip Apple M3 Pro đột phá kiến trúc GPU Dynamic Caching, màn hình Liquid Retina XDR độ sáng tối đa 1600 nits và thời lượng pin ấn tượng lên đến 18 tiếng.',
   'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=1200&q=80',
     'https://images.unsplash.com/photo-1611186871348-b1ce696e52c9?auto=format&fit=crop&w=1200&q=80'
   ],
   49990000, 47490000,
   '{"Màn hình": "14.2 inch Liquid Retina XDR 120Hz ProMotion 1600 nits", "Vi xử lý": "Apple M3 Pro 11-Core CPU, 14-Core GPU", "RAM": "18GB Unified Memory", "SSD": "512GB PCIe siêu tốc", "Cổng kết nối": "3x Thunderbolt 4, HDMI, SDXC, MagSafe 3", "Trọng lượng": "1.61 kg"}'
  ),

  -- 7. Dell XPS 13 9340
  ('laptops', 'Dell', 'Dell XPS 13 9340 Ultrabook', 'dell-xps-13',
   'Ultrabook siêu mỏng nhẹ cao cấp hàng đầu với thiết kế nhôm nguyên khối tối giản, bàn phím liền mạch không viền, thanh chức năng cảm ứng và vi xử lý Intel Core Ultra tích hợp AI NPU.',
   'https://images.unsplash.com/photo-1593642632823-8f785ba67e45?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1593642632823-8f785ba67e45?auto=format&fit=crop&w=1200&q=80'
   ],
   27990000, 26490000,
   '{"Màn hình": "13.4 inch FHD+ InfinityEdge 500 nits 100% sRGB", "Vi xử lý": "Intel Core Ultra 7 155H (16 nhân, 22 luồng)", "Đồ họa": "Intel Arc Graphics", "Trọng lượng": "1.19 kg", "Chất liệu": "Nhôm CNC & Kính Gorilla Glass 3"}'
  ),

  -- 8. ASUS ROG Zephyrus G14 (2024)
  ('laptops', 'ASUS', 'ASUS ROG Zephyrus G14 (2024)', 'asus-rog-zephyrus-g14-2024',
   'Chiến binh gaming mỏng nhẹ hoàn hảo sở hữu màn hình OLED ROG Nebula Display 3K 120Hz 0.2ms, CPU AMD Ryzen 9 AI và card đồ họa NVIDIA GeForce RTX 4060 cân mọi tựa game AAA.',
   'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?auto=format&fit=crop&w=1200&q=80'
   ],
   45990000, 43490000,
   '{"Màn hình": "14.0 inch 3K OLED ROG Nebula 120Hz 0.2ms G-Sync", "Vi xử lý": "AMD Ryzen 9 8945HS", "Đồ họa": "NVIDIA GeForce RTX 4060 8GB GDDR6", "Âm thanh": "Hệ thống 6 loa Dolby Atmos", "Trọng lượng": "1.50 kg"}'
  ),

  -- 9. LG Gram 16 2024
  ('laptops', 'LG', 'LG Gram 16 2024 Siêu Nhẹ', 'lg-gram-16-2024',
   'Kỷ lục laptop 16 inch nhẹ nhất thế giới chỉ 1.19kg, đạt tiêu chuẩn độ bền quân đội Mỹ MIL-STD-810H, viên pin khổng lồ 77Wh cho ngày làm việc bền bỉ suốt 24 giờ.',
   'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=1200&q=80'
   ],
   35990000, 32990000,
   '{"Màn hình": "16 inch WQXGA (2560x1600) IPS chống chói 99% DCI-P3", "Vi xử lý": "Intel Core Ultra 7 155H", "RAM": "16GB LPDDR5X", "Trọng lượng": "1.199 kg", "Thời lượng pin": "Lên tới 24 giờ (77Wh)"}'
  ),

  -- 10. iPad Pro 11 M4
  ('tablets', 'Apple', 'iPad Pro 11 inch M4 (Ultra Retina XDR)', 'ipad-pro-11-m4',
   'Chiếc iPad mỏng nhất từ trước đến nay (5.3mm), mang sức mạnh chip Apple M4 thế hệ mới cùng công nghệ màn hình đột phá Tandem OLED kép sáng nhất thế giới.',
   'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=1200&q=80'
   ],
   28990000, 27490000,
   '{"Màn hình": "11 inch Ultra Retina XDR Tandem OLED 120Hz ProMotion", "Vi xử lý": "Apple M4 (9-Core CPU / 10-Core GPU)", "Độ dày": "5.3 mm", "Hỗ trợ phụ kiện": "Apple Pencil Pro, Magic Keyboard M4", "Camera": "12MP Wide + Cảm biến LiDAR"}'
  ),

  -- 11. Samsung Galaxy Tab S9 Ultra
  ('tablets', 'Samsung', 'Samsung Galaxy Tab S9 Ultra 5G', 'samsung-galaxy-tab-s9-ultra',
   'Máy tính bảng đỉnh cao màn hình khổng lồ 14.6 inch Dynamic AMOLED 2X, chuẩn chống nước bụi IP68 toàn diện từ thân máy đến bút S-Pen, thay thế hoàn hảo cho máy tính xách tay với chế độ Samsung DeX.',
   'https://images.unsplash.com/photo-1561154464-82e9adf32764?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1561154464-82e9adf32764?auto=format&fit=crop&w=1200&q=80'
   ],
   26990000, 23990000,
   '{"Màn hình": "14.6 inch Dynamic AMOLED 2X 120Hz HDR10+", "Vi xử lý": "Snapdragon 8 Gen 2 for Galaxy", "Kháng nước & Bụi": "IP68", "Âm thanh": "Hệ thống 4 loa AKG Dolby Atmos", "Pin & Sạc": "11200 mAh, Sạc siêu nhanh 45W"}'
  ),

  -- 12. Sony WH-1000XM5
  ('audio', 'Sony', 'Tai nghe Sony WH-1000XM5 Chống Ồn', 'sony-wh-1000xm5',
   'Tai nghe chụp tai chống ồn hàng đầu thế giới với vi xử lý kép V1 & HD QN1, hệ thống 8 micro tối ưu theo môi trường và màng loa 30mm sợi carbon mang lại chất âm Hi-Res sắc nét thuần khiết.',
   'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=1200&q=80',
     'https://images.unsplash.com/photo-1484704849700-f032a568e944?auto=format&fit=crop&w=1200&q=80'
   ],
   7990000, 6890000,
   '{"Chống ồn": "Chủ động kép với chip QN1 & V1, 8 Micro tích hợp", "Thời lượng pin": "30 giờ bật ANC (Sạc nhanh 3 phút nghe 3 giờ)", "Codec hỗ trợ": "LDAC, AAC, SBC", "Kết nối": "Bluetooth 5.2 đa điểm kết nối 2 thiết bị"}'
  ),

  -- 13. AirPods Pro 2 USB-C
  ('audio', 'Apple', 'Apple AirPods Pro 2 (Hộp sạc MagSafe USB-C)', 'apple-airpods-pro-2-usbc',
   'Trang bị chip Apple H2 mang đến khả năng Khử tiếng ồn chủ động mạnh gấp đôi thế hệ trước, chế độ Âm thanh thích ứng (Adaptive Audio) và chuẩn kháng nước kháng bụi IP54 mới.',
   'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?auto=format&fit=crop&w=1200&q=80'
   ],
   5990000, 5490000,
   '{"Vi xử lý": "Apple H2 trong tai nghe, chip U1/U2 trong hộp sạc", "Tính năng âm thanh": "Chống ồn chủ động ANC, Chế độ xuyên âm thích ứng, Spatial Audio", "Cổng sạc": "USB-C, Hỗ trợ sạc MagSafe & Apple Watch charger", "Pin": "6 giờ (tai nghe), 30 giờ (kèm hộp)"}'
  ),

  -- 14. Marshall Stanmore III
  ('audio', 'Marshall', 'Loa Bluetooth Marshall Stanmore III', 'marshall-stanmore-iii',
   'Chiếc loa để bàn trứ danh công suất 80W Class D mạnh mẽ với âm trường rộng Dynamic Loudness, thiết kế phong cách vintage hoài cổ cùng núm xoay bằng đồng thau sang trọng.',
   'https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=format&fit=crop&w=1200&q=80'
   ],
   9990000, 8890000,
   '{"Công suất": "80W (1 x 50W Woofer + 2 x 15W Tweeter)", "Dải tần số": "45 - 20,000 Hz", "Kết nối": "Bluetooth 5.2, Cổng AUX 3.5mm, Cổng RCA analog", "Chất liệu": "Bọc da nhân tạo cao cấp, lưới ê-căng vintage"}'
  ),

  -- 15. Apple Watch Ultra 2
  ('smartwatches', 'Apple', 'Apple Watch Ultra 2 GPS + Cellular 49mm', 'apple-watch-ultra-2',
   'Đồng hồ thể thao dã ngoại chuyên nghiệp với vỏ Titanium chuẩn quân sự, màn hình độ sáng 3000 nits, chip S9 SiP thao tác Chạm hai lần (Double Tap) và khả năng lặn sâu 40m.',
   'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=1200&q=80'
   ],
   21990000, 20490000,
   '{"Kích thước vỏ": "49mm Titanium hàng không vũ trụ", "Màn hình": "OLED Sapphire độ sáng đỉnh 3000 nits", "GPS": "GPS tần số kép L1 và L5 chính xác cao", "Kháng nước": "100m, chứng nhận lặn EN13319 40m", "Pin": "36 giờ sử dụng thông thường, 72 giờ tiết kiệm pin"}'
  ),

  -- 16. Samsung Galaxy Watch 6 Classic
  ('smartwatches', 'Samsung', 'Samsung Galaxy Watch 6 Classic 47mm', 'samsung-galaxy-watch-6-classic',
   'Vẻ đẹp thời gian bất hủ với viền xoay bezel vật lý đặc trưng, mặt kính Sapphire chống trầy xước và gói cảm biến theo dõi sức khỏe BIA phân tích thành phần cơ thể chi tiết.',
   'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?auto=format&fit=crop&w=1200&q=80'
   ],
   8490000, 6990000,
   '{"Kích thước vỏ": "Thép không gỉ 47mm, Bezel xoay vật lý", "Mặt kính": "Kính Sapphire siêu bền", "Cảm biến": "Cảm biến BioActive 3 trong 1 (Điện tâm đồ ECG, Huyết áp, Thành phần cơ thể BIA)", "Hệ điều hành": "Wear OS Powered by Samsung"}'
  ),

  -- 17. Logitech MX Master 3S
  ('keyboards-mice', 'Logitech', 'Chuột Không Dây Logitech MX Master 3S', 'logitech-mx-master-3s',
   'Chuột công thái học biểu tượng cho lập trình viên và sáng tạo nội dung với cuộn siêu tốc MagSpeed 1000 dòng/giây, nút click giảm ồn 90% Quiet Clicks và cảm biến quang học 8000 DPI trên mặt kính.',
   'https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?auto=format&fit=crop&w=1200&q=80'
   ],
   2690000, 2290000,
   '{"Độ phân giải": "200 đến 8000 DPI (hoạt động trên mặt kính)", "Nút bấm": "Quiet Clicks siêu êm", "Cuộn trang": "Con lăn từ tính MagSpeed SmartShift", "Kết nối": "Bluetooth Low Energy & Đầu thu Logi Bolt USB", "Pin": "Dùng 70 ngày sau một lần sạc đầy USB-C"}'
  ),

  -- 18. Keychron Q1 Pro
  ('keyboards-mice', 'Keychron', 'Bàn Phím Cơ Không Dây Keychron Q1 Pro Custom', 'keychron-q1-pro',
   'Bàn phím cơ Custom cao cấp layout 75% vỏ nhôm CNC nguyên khối anodized, núm xoay đa năng Knob, thiết kế đệm đôi Double-Gasket êm ái và hỗ trợ QMK/VIA tùy biến toàn diện.',
   'https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=1200&q=80'
   ],
   4790000, 4390000,
   '{"Layout": "75% (81 phím) có núm xoay kim loại xoay mượt", "Vỏ khung": "Nhôm 6063 CNC nguyên khối", "Mạch": "Hotswap xuôi 5-pin hỗ trợ đổi switch nhanh", "Keycap": "KSA profile PBT Double-shot", "Kết nối": "Bluetooth 5.1 & Type-C có dây 1000Hz"}'
  ),

  -- 19. Dell UltraSharp U2724D
  ('monitors', 'Dell', 'Màn Hình Dell UltraSharp U2724D 27" 2K 120Hz', 'dell-ultrasharp-u2724d',
   'Màn hình đồ họa đầu tiên sở hữu tấm nền IPS Black công nghệ cao với tỷ lệ tương phản 2000:1, tần số quét 120Hz mượt mà và cảm biến ánh sáng xung quanh tự động điều chỉnh độ sáng.',
   'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?auto=format&fit=crop&w=1200&q=80'
   ],
   10990000, 9890000,
   '{"Kích thước": "27 inch IPS Black chống chói", "Độ phân giải": "2K QHD (2560 x 1440) @ 120Hz", "Độ bao phủ màu": "98% DCI-P3, 100% sRGB, Delta E < 2", "Cổng kết nối": "DisplayPort 1.4, HDMI 2.1, USB-C Hub 90W PD", "Chân đế": "Xoay dọc 90 độ, nâng hạ công thái học"}'
  ),

  -- 20. Samsung Odyssey OLED G8
  ('monitors', 'Samsung', 'Màn Hình Gaming Samsung Odyssey OLED G8 34"', 'samsung-odyssey-oled-g8',
   'Tuyệt phẩm màn hình cong 34 inch tỷ lệ 21:9 Ultra-WQHD công nghệ OLED lượng tử, tốc độ làm tươi 175Hz, thời gian đáp ứng chớp nhoáng 0.03ms và vỏ kim loại siêu mỏng chỉ 3.9mm.',
   'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80'
   ],
   28990000, 25490000,
   '{"Kích thước": "34 inch cong 1800R tỷ lệ siêu rộng 21:9", "Độ phân giải": "UWQHD (3440 x 1440) @ 175Hz", "Thời gian phản hồi": "0.03ms (GtG) siêu tốc", "Công nghệ hiển thị": "Neo Quantum Processor OLED", "Đèn nền": "CoreSync & Core Lighting+ đổi màu theo game"}'
  ),

  -- 21. Củ sạc Anker Prime 100W GaN
  ('accessories', 'Anker', 'Củ Sạc Nhanh Anker Prime 100W GaN 3 Cổng', 'anker-prime-100w-gan',
   'Công nghệ GaNPrime tân tiến thu nhỏ kích thước củ sạc 43% so với sạc Apple 96W, 3 cổng sạc (2 USB-C + 1 USB-A) sạc cùng lúc MacBook, iPhone và iPad với thuật toán phân bổ điện năng thông minh PowerIQ 4.0.',
   'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=1200&q=80'
   ],
   1690000, 1390000,
   '{"Tổng công suất": "100W Max chuẩn sạc PD 3.0 PPS", "Cổng kết nối": "2x USB-C (100W Max mỗi cổng), 1x USB-A (22.5W)", "Công nghệ": "GaNPrime & ActiveShield 2.0 kiểm soát nhiệt độ", "Kích thước": "Cực nhỏ gọn, chân gập 90 độ tiện lợi"}'
  ),

  -- 22. Pin sạc dự phòng Anker 737 24000mAh
  ('accessories', 'Anker', 'Pin Sạc Dự Phòng Anker 737 Power Bank (PowerCore 24K 140W)', 'anker-737-power-bank-24000mah',
   'Trạm năng lượng di động sở hữu công suất sạc hai chiều 140W đỉnh cao chuẩn Power Delivery 3.1, dung lượng lớn 24.000mAh và màn hình kỹ thuật số hiển thị điện áp, công suất và thời lượng pin trực quan.',
   'https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?auto=format&fit=crop&w=800&q=80',
   ARRAY[
     'https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?auto=format&fit=crop&w=1200&q=80'
   ],
   2990000, 2490000,
   '{"Dung lượng": "24,000 mAh (86.4Wh sạc được cho MacBook Pro đầy 1.3 lần)", "Công suất sạc ra/vào": "140W Ultra-Fast chuẩn PD 3.1", "Màn hình": "Smart Digital Display màu sắc nét", "Cổng sạc": "2x USB-C 140W + 1x USB-A 18W"}'
  )
) AS v(cat_slug, brand_name, name, slug, description, thumbnail_url, images, base_price, discount_price, specifications)
JOIN public.categories c ON c.slug = v.cat_slug
JOIN public.brands b ON b.name = v.brand_name
ON CONFLICT (slug) DO UPDATE SET
  category_id = EXCLUDED.category_id,
  brand_id = EXCLUDED.brand_id,
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  thumbnail_url = EXCLUDED.thumbnail_url,
  images = EXCLUDED.images,
  base_price = EXCLUDED.base_price,
  discount_price = EXCLUDED.discount_price,
  specifications = EXCLUDED.specifications,
  is_active = true,
  updated_at = NOW();

-- 4. BỔ SUNG & CẬP NHẬT BIẾN THỂ SẢN PHẨM (PRODUCT VARIANTS)
INSERT INTO public.product_variants (product_id, sku, attributes, price_adjustment, cost_price, stock_quantity, is_active)
SELECT
  p.id,
  v.sku,
  v.attributes::jsonb,
  v.price_adjustment,
  v.cost_price,
  v.stock_quantity,
  true
FROM (VALUES
  -- 1. iPhone 15 Pro Max
  ('iphone-15-pro-max', 'IP15PM-256-NAT', '{"Màu sắc": "Titan Tự nhiên", "Dung lượng": "256GB"}', 0, 25000000, 35),
  ('iphone-15-pro-max', 'IP15PM-512-NAT', '{"Màu sắc": "Titan Tự nhiên", "Dung lượng": "512GB"}', 6000000, 30000000, 20),
  ('iphone-15-pro-max', 'IP15PM-256-BLU', '{"Màu sắc": "Titan Xanh", "Dung lượng": "256GB"}', 0, 25000000, 25),
  ('iphone-15-pro-max', 'IP15PM-256-BLK', '{"Màu sắc": "Titan Đen", "Dung lượng": "256GB"}', 0, 25000000, 30),

  -- 2. Samsung Galaxy S24 Ultra
  ('samsung-galaxy-s24-ultra', 'S24U-12-256-GRY', '{"Màu sắc": "Xám Titan", "Dung lượng": "256GB"}', 0, 24000000, 40),
  ('samsung-galaxy-s24-ultra', 'S24U-12-512-GRY', '{"Màu sắc": "Xám Titan", "Dung lượng": "512GB"}', 4500000, 27500000, 25),
  ('samsung-galaxy-s24-ultra', 'S24U-12-256-BLK', '{"Màu sắc": "Đen Titan", "Dung lượng": "256GB"}', 0, 24000000, 30),

  -- 3. iPhone 15
  ('iphone-15', 'IP15-128-BLK', '{"Màu sắc": "Đen", "Dung lượng": "128GB"}', 0, 16000000, 50),
  ('iphone-15', 'IP15-256-BLK', '{"Màu sắc": "Đen", "Dung lượng": "256GB"}', 3000000, 18500000, 30),
  ('iphone-15', 'IP15-256-BLU', '{"Màu sắc": "Xanh Dương", "Dung lượng": "256GB"}', 3000000, 18500000, 20),

  -- 4. Samsung Galaxy S24
  ('samsung-galaxy-s24', 'S24-8-256', '{"Màu sắc": "Vàng Amber", "Dung lượng": "256GB"}', 0, 15000000, 40),
  ('samsung-galaxy-s24', 'S24-8-512', '{"Màu sắc": "Đen Onyx", "Dung lượng": "512GB"}', 3500000, 17500000, 25),

  -- 5. Xiaomi 14 Ultra
  ('xiaomi-14-ultra', 'MI14U-16-512-BLK', '{"Màu sắc": "Đen Da Vegan", "Dung lượng": "512GB"}', 0, 22000000, 15),
  ('xiaomi-14-ultra', 'MI14U-16-512-WHT', '{"Màu sắc": "Trắng Da Vegan", "Dung lượng": "512GB"}', 0, 22000000, 12),

  -- 6. MacBook Pro 14 M3 Pro
  ('macbook-pro-14-m3-pro', 'MBP14-M3P-18-512-BLK', '{"Màu sắc": "Space Black", "Cấu hình": "18GB RAM / 512GB SSD"}', 0, 42000000, 15),
  ('macbook-pro-14-m3-pro', 'MBP14-M3P-36-1TB-BLK', '{"Màu sắc": "Space Black", "Cấu hình": "36GB RAM / 1TB SSD"}', 12000000, 52000000, 8),
  ('macbook-pro-14-m3-pro', 'MBP14-M3P-18-512-SLV', '{"Màu sắc": "Silver", "Cấu hình": "18GB RAM / 512GB SSD"}', 0, 42000000, 10),

  -- 7. Dell XPS 13
  ('dell-xps-13', 'XPS13-8-256',  '{"Màu sắc": "Platinum", "Cấu hình": "16GB RAM / 512GB SSD"}', 0, 23000000, 15),
  ('dell-xps-13', 'XPS13-16-512', '{"Màu sắc": "Graphite", "Cấu hình": "16GB RAM / 512GB SSD"}', 0, 23000000, 10),
  ('dell-xps-13', 'XPS13-32-1TB', '{"Màu sắc": "Graphite", "Cấu hình": "32GB RAM / 1TB SSD"}',   9000000, 31000000, 5),

  -- 8. ASUS ROG Zephyrus G14
  ('asus-rog-zephyrus-g14-2024', 'G14-R9-16-1TB-WHT', '{"Màu sắc": "Trắng Ánh Trăng", "Cấu hình": "RTX 4060 / 16GB / 1TB"}', 0, 38000000, 12),
  ('asus-rog-zephyrus-g14-2024', 'G14-R9-32-1TB-GRY', '{"Màu sắc": "Xám Nhật Thực", "Cấu hình": "RTX 4070 / 32GB / 1TB"}', 6000000, 43000000, 8),

  -- 9. LG Gram 16 2024
  ('lg-gram-16-2024', 'LGGRAM16-16-512-BLK', '{"Màu sắc": "Đen Obsidian", "Cấu hình": "Ultra 7 / 16GB / 512GB"}', 0, 29000000, 14),
  ('lg-gram-16-2024', 'LGGRAM16-32-1TB-BLK', '{"Màu sắc": "Đen Obsidian", "Cấu hình": "Ultra 7 / 32GB / 1TB"}', 5000000, 34000000, 7),

  -- 10. iPad Pro 11 M4
  ('ipad-pro-11-m4', 'IPAD-M4-256-BLK', '{"Màu sắc": "Space Black", "Kết nối": "WiFi 256GB"}', 0, 24000000, 20),
  ('ipad-pro-11-m4', 'IPAD-M4-512-BLK', '{"Màu sắc": "Space Black", "Kết nối": "WiFi 512GB"}', 5500000, 29000000, 15),
  ('ipad-pro-11-m4', 'IPAD-M4-256-5G-SLV', '{"Màu sắc": "Silver", "Kết nối": "5G Cellular 256GB"}', 4500000, 28000000, 10),

  -- 11. Samsung Galaxy Tab S9 Ultra
  ('samsung-galaxy-tab-s9-ultra', 'TABS9U-12-256-GRF', '{"Màu sắc": "Graphite", "Bộ nhớ": "12GB / 256GB WiFi"}', 0, 21000000, 18),
  ('samsung-galaxy-tab-s9-ultra', 'TABS9U-12-512-GRF', '{"Màu sắc": "Graphite", "Bộ nhớ": "12GB / 512GB 5G"}', 6000000, 26000000, 10),

  -- 12. Sony WH-1000XM5
  ('sony-wh-1000xm5', 'WH1000XM5-BLK', '{"Màu sắc": "Đen Nhám"}', 0, 5800000, 25),
  ('sony-wh-1000xm5', 'WH1000XM5-SLV', '{"Màu sắc": "Bạc Bạch Kim"}', 0, 5800000, 20),
  ('sony-wh-1000xm5', 'WH1000XM5-BLU', '{"Màu sắc": "Xanh Midnight"}', 200000, 6000000, 15),

  -- 13. AirPods Pro 2 USB-C
  ('apple-airpods-pro-2-usbc', 'APP2-USBC-WHT', '{"Màu sắc": "Trắng"}', 0, 4500000, 45),

  -- 14. Marshall Stanmore III
  ('marshall-stanmore-iii', 'STAM3-BLK', '{"Màu sắc": "Đen Cổ Điển"}', 0, 7500000, 15),
  ('marshall-stanmore-iii', 'STAM3-BRW', '{"Màu sắc": "Nâu Vintage"}', 300000, 7800000, 12),
  ('marshall-stanmore-iii', 'STAM3-CRM', '{"Màu sắc": "Trắng Kem"}', 300000, 7800000, 10),

  -- 15. Apple Watch Ultra 2
  ('apple-watch-ultra-2', 'AWU2-ALPINE-ORG', '{"Phiên bản dây": "Dây Alpine Loop Cam"}', 0, 18000000, 15),
  ('apple-watch-ultra-2', 'AWU2-TRAIL-BLK',  '{"Phiên bản dây": "Dây Trail Loop Đen/Xám"}', 0, 18000000, 20),
  ('apple-watch-ultra-2', 'AWU2-OCEAN-BLU',  '{"Phiên bản dây": "Dây Ocean Xanh Biển"}', 0, 18000000, 12),

  -- 16. Samsung Galaxy Watch 6 Classic
  ('samsung-galaxy-watch-6-classic', 'GW6C-43-BLK', '{"Kích thước": "43mm", "Màu sắc": "Đen"}', 0, 5800000, 20),
  ('samsung-galaxy-watch-6-classic', 'GW6C-47-SLV', '{"Kích thước": "47mm", "Màu sắc": "Bạc"}', 1000000, 6600000, 15),

  -- 17. Logitech MX Master 3S
  ('logitech-mx-master-3s', 'MXM3S-GRA', '{"Màu sắc": "Xám Than (Graphite)"}', 0, 1800000, 50),
  ('logitech-mx-master-3s', 'MXM3S-PLT', '{"Màu sắc": "Trắng Xám (Pale Gray)"}', 0, 1800000, 30),

  -- 18. Keychron Q1 Pro
  ('keychron-q1-pro', 'Q1PRO-RED-BLK', '{"Switch": "Red Switch (Êm)", "Màu sắc": "Carbon Black"}', 0, 3600000, 18),
  ('keychron-q1-pro', 'Q1PRO-BRN-BLK', '{"Switch": "Brown Switch (Khấc)", "Màu sắc": "Carbon Black"}', 0, 3600000, 22),
  ('keychron-q1-pro', 'Q1PRO-BLU-SLV', '{"Switch": "Banana Switch (Nảy)", "Màu sắc": "Silver Grey"}', 200000, 3800000, 14),

  -- 19. Dell UltraSharp U2724D
  ('dell-ultrasharp-u2724d', 'U2724D-STD', '{"Kích thước": "27 inch", "Độ phân giải": "2K QHD (2560 x 1440)"}', 0, 8500000, 20),

  -- 20. Samsung Odyssey OLED G8
  ('samsung-odyssey-oled-g8', 'G8-OLED-34', '{"Kích thước": "34 inch Cong", "Độ phân giải": "UWQHD (3440 x 1440)"}', 0, 22000000, 8),

  -- 21. Củ sạc Anker Prime 100W GaN
  ('anker-prime-100w-gan', 'ANKER-100W-BLK', '{"Màu sắc": "Đen Nhám"}', 0, 1000000, 60),

  -- 22. Pin sạc dự phòng Anker 737 24000mAh
  ('anker-737-power-bank-24000mah', 'ANKER-737-24K', '{"Màu sắc": "Xám Titan"}', 0, 1900000, 35)
) AS v(prod_slug, sku, attributes, price_adjustment, cost_price, stock_quantity)
JOIN public.products p ON p.slug = v.prod_slug
ON CONFLICT (sku) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  attributes = EXCLUDED.attributes,
  price_adjustment = EXCLUDED.price_adjustment,
  cost_price = EXCLUDED.cost_price,
  stock_quantity = EXCLUDED.stock_quantity,
  is_active = true,
  updated_at = NOW();

-- 5. TẠO TÀI KHOẢN REVIEWER MẪU (AN TOÀN CHO CẢ SUPABASE & LOCAL POSTGRESQL)
DO $$
BEGIN
  -- 5.1 Tạo trong schema auth.users nếu bảng tồn tại
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
    INSERT INTO auth.users (id, email, raw_user_meta_data)
    VALUES
      ('11111111-1111-1111-1111-111111111111', 'reviewer1@techgadget.local', '{"full_name": "Nguyễn Hoàng Nam"}'::jsonb),
      ('22222222-2222-2222-2222-222222222222', 'reviewer2@techgadget.local', '{"full_name": "Lê Phương Thảo"}'::jsonb),
      ('33333333-3333-3333-3333-333333333333', 'reviewer3@techgadget.local', '{"full_name": "Trần Tuấn Anh"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
  END IF;

  -- 5.2 Tạo hoặc cập nhật hồ sơ khách hàng mẫu trong public.profiles
  INSERT INTO public.profiles (id, full_name, avatar_url, role)
  VALUES
    ('11111111-1111-1111-1111-111111111111', 'Nguyễn Hoàng Nam', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80', 'customer'),
    ('22222222-2222-2222-2222-222222222222', 'Lê Phương Thảo', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80', 'customer'),
    ('33333333-3333-3333-3333-333333333333', 'Trần Tuấn Anh', 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=200&q=80', 'customer')
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    avatar_url = EXCLUDED.avatar_url;

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Bỏ qua tạo tài khoản mẫu do hạn chế phân quyền auth: %', SQLERRM;
END $$;

-- 6. BỔ SUNG ĐÁNH GIÁ MẪU (REVIEWS) ĐỂ APP HIỂN THỊ ĐỦ SAO VÀ SỐ LƯỢNG ĐÁNH GIÁ
INSERT INTO public.reviews (product_id, user_id, rating, comment)
SELECT p.id, r.user_id, r.rating, r.comment
FROM (VALUES
  ('iphone-15-pro-max', '11111111-1111-1111-1111-111111111111'::uuid, 5, 'Máy cầm rất nhẹ tay nhờ khung titan, camera zoom 5x chụp nét căng!'),
  ('iphone-15-pro-max', '22222222-2222-2222-2222-222222222222'::uuid, 5, 'Dùng cực kỳ mượt mà, thời lượng pin trâu dùng cả ngày không hết.'),
  ('samsung-galaxy-s24-ultra', '11111111-1111-1111-1111-111111111111'::uuid, 5, 'Màn hình chống chói ra ngoài nắng nhìn rõ mồn một. Tính năng Galaxy AI Circle to Search rất tiện.'),
  ('macbook-pro-14-m3-pro', '33333333-3333-3333-3333-333333333333'::uuid, 5, 'Màu Space Black cực đẹp, máy render video 4K êm ru không một tiếng quạt gió.'),
  ('sony-wh-1000xm5', '22222222-2222-2222-2222-222222222222'::uuid, 5, 'Chống ồn đỉnh cao của Sony, đeo làm việc cả ngày ở quán cà phê cực kỳ yên tĩnh.'),
  ('apple-airpods-pro-2-usbc', '11111111-1111-1111-1111-111111111111'::uuid, 5, 'Âm thanh không gian Spatial Audio nghe cực hay, cổng Type-C tiện lợi không cần đổi cáp.'),
  ('logitech-mx-master-3s', '11111111-1111-1111-1111-111111111111'::uuid, 5, 'Con lăn điện từ mượt mà, click cực kỳ êm ái, rất đáng tiền cho dân văn phòng và coder.'),
  ('keychron-q1-pro', '33333333-3333-3333-3333-333333333333'::uuid, 5, 'Bàn phím nhôm đầm tay chắc chắn, âm thanh gõ thock rất đã tai, Bluetooth kết nối mượt mà.'),
  ('dell-ultrasharp-u2724d', '33333333-3333-3333-3333-333333333333'::uuid, 5, 'Tấm nền IPS Black màu đen sâu, tần số 120Hz làm việc văn phòng và thiết kế đồ họa rất dễ chịu.')
) AS r(prod_slug, user_id, rating, comment)
JOIN public.products p ON p.slug = r.prod_slug
WHERE EXISTS (SELECT 1 FROM public.profiles WHERE id = r.user_id)
ON CONFLICT (product_id, user_id) DO UPDATE SET
  rating = EXCLUDED.rating,
  comment = EXCLUDED.comment,
  updated_at = NOW();

-- 7. THÔNG BÁO HOÀN THÀNH
DO $$
BEGIN
  RAISE NOTICE '=> Đã nạp thành công bộ dữ liệu Tech Gadget Store đầy đủ: 8 Danh mục, 11 Thương hiệu, 22 Sản phẩm, 40+ Biến thể!';
END $$;
