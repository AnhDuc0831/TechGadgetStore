# TECHNICAL REPORT: MOBILE ECOMMERCE APPLICATION

* **Course:** Flutter Application Development (PRM392 / Mobile Programming)
* **Team Size:** 5 Members
* **Project Name:** TechGadget App (TechGadget E-Commerce Solution)
* **Date:** 2026

---

## 1. Team Introduction

| STT | Full Name (Họ và Tên) | Role | Responsibilities | Contribution |
| :---: | :--- | :--- | :--- | :---: |
| 1 | **Châu Anh Đức** | Team Leader & Full-Stack Architect / AI & DevOps | - Thiết kế kiến trúc tổng thể (.NET 8 Clean Architecture & Flutter MultiProvider).<br>- Tích hợp Supabase Authentication & Google OAuth SSO.<br>- Tích hợp Trợ lý Trí tuệ Nhân tạo Google Gemini (Customer AI Chat & Admin Analytics AI).<br>- Đóng gói Docker, cấu hình CI/CD và triển khai Cloud hosting (Render). | 20% |
| 2 | **Nguyễn Tiến Lộc** | Backend & Mobile Payment / Order Specialist | - Thiết kế nghiệp vụ Đặt hàng (Checkout Flow) và Quản lý Đơn hàng.<br>- Tích hợp Cổng thanh toán trực tuyến PayOS (VietQR NAPAS 24/7) và xử lý bảo mật PayOS Webhook.<br>- Xây dựng màn hình Payment WebView, Order Detail và bộ Unit Tests cho Order Service / Provider. | 20% |
| 3 | **Trần Hữu Triết** | Mobile Developer (Cart & Checkout Flow) | - Xây dựng Giao diện & Logic Giỏ hàng (Cart Screen, Cart Provider, tăng/giảm số lượng, chọn món).<br>- Xây dựng luồng Checkout Screen và màn hình thông báo đặt hàng COD thành công.<br>- Viết Unit Test cho Cart Model & Format tiền tệ VND. | 20% |
| 4 | **Võ Hoàng Minh** | Mobile & API Developer (Product Catalog & Search) | - Xây dựng API và Database cho Danh mục (Categories), Thương hiệu (Brands), Sản phẩm (Products).<br>- Thiết kế màn hình Trang chủ (HomeScreen), Product Card, Bộ lọc đa tiêu chí (Product Filter Sheet).<br>- Xây dựng màn hình Chi tiết sản phẩm (Product Detail Screen, chọn biến thể SKU, thư viện ảnh). | 20% |
| 5 | **Nguyễn Tất Thành Luân** | Admin & Analytics Developer (Admin Portal & Dashboard) | - Xây dựng hệ thống Quản trị viên (Admin Dashboard) với biểu đồ thống kê động qua thư viện `fl_chart`.<br>- Xây dựng chức năng quản lý danh mục và CRUD sản phẩm cho Admin (Add/Edit/Delete Product).<br>- Xây dựng màn hình quản lý trạng thái đơn hàng (Admin Orders Management). | 20% |

---

## 2. Case Study

* **Project Title:** TechGadget - Giải pháp ứng dụng thương mại điện tử mua sắm thiết bị & phụ kiện công nghệ thông minh tích hợp thanh toán số PayOS và Trợ lý AI Gemini.
* **Domain:** Online Sales System / Mobile E-Commerce (M-Commerce).
* **Description:**  
  Trong kỷ nguyên số, nhu cầu sở hữu và nâng cấp các thiết bị công nghệ (Smartphone, Laptop, Tablet, Smartwatch, Phụ kiện âm thanh, Thiết bị thông minh) của học sinh, sinh viên và người đi làm ngày càng tăng cao. Tuy nhiên, các ứng dụng hiện nay thường cồng kềnh, thiếu tính năng hỗ trợ tư vấn tức thời và quy trình thanh toán phức tạp.  
  
  **TechGadget** được phát triển nhằm giải quyết triệt để những khó khăn trên bằng một ứng dụng di động đa nền tảng (Flutter) mượt mà, kết hợp với hệ thống Backend ASP.NET Core 8 chuẩn công nghiệp và cơ sở dữ liệu đám mây PostgreSQL/Supabase:
  * **Trải nghiệm mua sắm thông minh:** Người dùng dễ dàng khám phá hàng nghìn sản phẩm chính hãng với hình ảnh trực quan, bộ lọc thông số kỹ thuật chi tiết và hỗ trợ chọn biến thể (màu sắc, cấu hình RAM/SSD).
  * **Trợ lý AI Gemini đồng hành:** Khách hàng có thể tương tác trực tiếp với Trợ lý AI để được gợi ý thiết bị phù hợp với ngân sách và nhu cầu học tập/làm việc; đồng thời Quản trị viên có thể trò chuyện với AI để truy vấn nhanh dữ liệu doanh thu, sản phẩm bán chạy mà không cần xem báo cáo thủ công.
  * **Thanh toán trực tuyến hiện đại:** Tích hợp cổng thanh toán tự động PayOS thông qua mã chuẩn VietQR NAPAS 24/7, xác nhận đơn hàng theo thời gian thực (Real-time Webhook) và hỗ trợ phương thức trả tiền mặt khi nhận hàng (COD).
  * **Bản đồ giao vận & Theo dõi hành trình:** Tích hợp OpenStreetMap và GPS để tự động định vị địa chỉ người nhận và mô phỏng hành trình giao hàng trực quan trên bản đồ.

---

## 3. Business Analysis / System Design

### 3.1. Requirements

#### Functional Requirements (Yêu cầu chức năng)
1. **Phân hệ Khách hàng (Customer):**
   * **Xác thực người dùng:** Đăng ký tài khoản, đăng nhập qua Email/Mật khẩu hoặc Google Sign-In (OAuth SSO), xem và cập nhật hồ sơ cá nhân (Họ tên, SĐT, Địa chỉ, Avatar).
   * **Khám phá sản phẩm:** Xem danh sách sản phẩm theo danh mục/thương hiệu, tìm kiếm từ khóa theo thời gian thực, lọc sản phẩm theo khoảng giá, trạng thái còn hàng và sắp xếp.
   * **Chi tiết sản phẩm & Biến thể:** Xem thông tin cấu hình, chọn biến thể (SKU, Màu sắc, Dung lượng), xem giá tương ứng và đánh giá/nhận xét (Review & Rating Stars).
   * **Quản lý Giỏ hàng:** Thêm sản phẩm vào giỏ, điều chỉnh số lượng, xóa sản phẩm, chọn/bỏ chọn từng sản phẩm để tiến hành thanh toán, tính tổng tiền tự động.
   * **Quy trình Thanh toán (Checkout):** Nhập/chọn thông tin giao hàng qua GPS định vị vị trí trên bản đồ, chọn phương thức thanh toán (COD hoặc Chuyển khoản QR qua PayOS), ghi chú đơn hàng.
   * **Cổng thanh toán PayOS:** Nhúng WebView quét mã VietQR tự động, xử lý callback thanh toán thành công/thất bại.
   * **Theo dõi Đơn hàng:** Xem lịch sử mua hàng theo từng trạng thái (Tất cả, Chờ xử lý, Đang giao, Đã hoàn thành, Đã hủy); Hủy đơn khi chưa xác nhận; Theo dõi vị trí đơn hàng trên bản đồ thời gian thực (Order Tracking Map).
   * **Trợ lý Khách hàng AI:** Chat trực tiếp với Google Gemini AI để nhận tư vấn mua sắm, so sánh thông số kỹ thuật.

2. **Phân hệ Quản trị viên (Admin):**
   * **Bảng điều khiển (Admin Dashboard):** Báo cáo tổng doanh thu, số lượng đơn hàng, số khách hàng mới; Biểu đồ doanh thu trực quan theo ngày/tháng sử dụng `fl_chart`.
   * **Quản lý Sản phẩm (Product Management):** Xem danh sách sản phẩm, thêm sản phẩm mới (Upload ảnh, giá, cấu hình biến thể), chỉnh sửa thông tin, ẩn/hiện sản phẩm.
   * **Quản lý Đơn hàng (Order Management):** Xem toàn bộ đơn hàng của khách hàng, lọc theo trạng thái, cập nhật tiến độ đơn hàng (Pending -> Processing -> Shipped -> Delivered / Cancelled).
   * **Trợ lý Quản trị AI (Admin Analytics AI):** AI truy vấn cơ sở dữ liệu để giải đáp tức thời về doanh số, tồn kho và đề xuất chiến lược nhập hàng.

#### Non-functional Requirements (Yêu cầu phi chức năng)
* **Hiệu năng (Performance):** Tốc độ phản hồi API trung bình < 400ms. Thời gian tải danh sách và chuyển màn hình trên ứng dụng < 1.5 giây. Sử dụng ảnh nén và cache để tối ưu lưu lượng mạng.
* **Bảo mật (Security):** Toàn bộ giao tiếp sử dụng HTTPS/TLS. Token JWT Bearer Token mã hóa từ Supabase Auth xác thực người dùng. Chữ ký số HMAC_SHA256 bảo vệ Webhook thanh toán PayOS chống giả mạo. Áp dụng RLS (Row Level Security) và Trigger `prevent_role_escalation` trong cơ sở dữ liệu ngăn chặn hành vi tự nâng quyền Admin.
* **Tính khả dụng (Usability):** Giao diện theo nguyên tắc Material Design 3, màu sắc hiện đại, thông báo lỗi (SnackBar/Dialog) rõ ràng, thân thiện với người dùng di động.
* **Độ tin cậy & Toàn vẹn (Reliability & Integrity):** Dữ liệu đơn hàng và giao dịch được quản lý bằng Database Transaction, kiểm tra tồn kho nghiêm ngặt tránh hiện tượng overselling.

---

### 3.2. Application Architecture

Hệ thống được thiết kế theo mô hình **Client-Server đa tầng (Multi-tier Architecture)** hiện đại, tách biệt hoàn toàn giữa ứng dụng di động Flutter và hệ sinh thái Backend API:

```
[ FLUTTER CLIENT APP ]
   ├── Presentation Layer (Screens, Custom Widgets, Modals)
   ├── State Management Layer (ChangeNotifierProviders: Auth, Cart, Order)
   └── Data & Service Layer (Http REST Clients, Supabase Client, Geocoding)
              │
              ▼ (HTTPS / JSON REST API / JWT Token)
[ ASP.NET CORE 8 BACKEND API ]
   ├── API / Presentation Layer (Controllers: Products, Cart, Orders, Admin, AI, PayOS)
   ├── Business Logic / Service Layer (OrderService, ProductService, AiGeminiService,...)
   ├── Data Access Layer (Repositories, Unit of Work, Entity Framework Core)
   └── External Integrations (PayOS Gateway, Google Gemini API SDK)
              │
              ▼ (PostgreSQL Wire Protocol)
[ POSTGRESQL / SUPABASE CLOUD DATABASE ]
```

* **UI Layer (Presentation):** Bao gồm các StatefulWidget và StatelessWidget được tổ chức khoa học theo từng màn hình (HomeScreen, CartScreen, CheckoutScreen, AdminDashboardScreen,...).
* **Business Logic Layer (Provider):** Sử dụng thư viện `provider` làm hạt nhân quản lý trạng thái (`AuthProvider`, `CartProvider`, `OrderProvider`), giúp đồng bộ dữ liệu xuyên suốt giữa các widget mà không cần truyền tham số thủ công (prop drilling).
* **Data & Services Layer (Client):** Giao tiếp với Backend qua HTTP Client (`http: ^1.6.0`), tương tác xác thực và lưu phiên với Supabase SDK (`supabase_flutter`).
* **Backend Clean Architecture (.NET 8):** Phân chia rõ ràng thành các tầng `BusinessObjects`, `DataAccessObjects`, `Repositories`, `Services` và `API`, tuân thủ nguyên lý Single Responsibility và Dependency Injection.

---

### 3.3. Database Design (PostgreSQL / Supabase Schema)

Hệ thống cơ sở dữ liệu quan hệ được thiết kế chuẩn hóa (3NF) trên PostgreSQL nhằm đảm bảo tính toàn vẹn và hiệu năng cao.

#### 1. Bảng `profiles` (Thông tin người dùng mở rộng)
| Tên cột | Kiểu dữ liệu | Ràng buộc | Giải thích |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, REFERENCES auth.users(id) | Khóa chính, liên kết trực tiếp với tài khoản Supabase Auth. |
| `full_name` | TEXT | NULL | Họ và tên hiển thị của người dùng. |
| `avatar_url` | TEXT | NULL | Đường dẫn ảnh đại diện cá nhân. |
| `phone` | TEXT | NULL | Số điện thoại liên hệ phục vụ giao hàng. |
| `role` | public.user_role | NOT NULL, DEFAULT 'customer' | Phân quyền tài khoản (`customer` hoặc `admin`). |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Thời điểm khởi tạo tài khoản. |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Thời điểm cập nhật thông tin gần nhất. |

#### 2. Bảng `categories` (Danh mục sản phẩm)
| Tên cột | Kiểu dữ liệu | Ràng buộc | Giải thích |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Khóa chính định danh danh mục. |
| `name` | TEXT | NOT NULL | Tên danh mục (Điện thoại, Laptop, Phụ kiện,...). |
| `slug` | TEXT | NOT NULL, UNIQUE | Đường dẫn thân thiện cho danh mục. |
| `description` | TEXT | NULL | Mô tả chi tiết danh mục. |
| `image_url` | TEXT | NULL | Ảnh biểu tượng đại diện danh mục. |

#### 3. Bảng `products` (Sản phẩm công nghệ)
| Tên cột | Kiểu dữ liệu | Ràng buộc | Giải thích |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Khóa chính sản phẩm. |
| `category_id` | UUID | NOT NULL, REFERENCES categories(id) | Liên kết với danh mục sản phẩm. |
| `brand_id` | UUID | NOT NULL, REFERENCES brands(id) | Liên kết với hãng sản xuất (Apple, Samsung,...). |
| `name` | TEXT | NOT NULL | Tên thương mại đầy đủ của sản phẩm. |
| `slug` | TEXT | NOT NULL, UNIQUE | Chuỗi định danh URL duy nhất. |
| `description` | TEXT | NULL | Bài viết mô tả thông số kỹ thuật và tính năng. |
| `thumbnail_url` | TEXT | NULL | Link ảnh đại diện sản phẩm. |
| `base_price` | NUMERIC(14,2) | NOT NULL, CHECK (base_price >= 0) | Giá cơ sở khởi điểm của sản phẩm. |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE | Trạng thái hiển thị mở bán sản phẩm. |

#### 4. Bảng `product_variants` (Biến thể sản phẩm theo cấu hình/màu sắc)
| Tên cột | Kiểu dữ liệu | Ràng buộc | Giải thích |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Khóa chính định danh biến thể. |
| `product_id` | UUID | NOT NULL, REFERENCES products(id) ON DELETE CASCADE | Sản phẩm cha của biến thể. |
| `sku` | TEXT | NOT NULL, UNIQUE | Mã quản lý kho hàng duy nhất (VD: IP15PM-256-TI). |
| `attributes` | JSONB | NOT NULL, DEFAULT '{}'::jsonb | Thuộc tính biến thể (VD: `{"color":"Titan","ram":"8GB"}`). |
| `price_adjustment` | NUMERIC(14,2) | NOT NULL, DEFAULT 0 | Mức giá chênh lệch so với `base_price`. |
| `stock_quantity` | INTEGER | NOT NULL, CHECK (stock_quantity >= 0) | Số lượng tồn kho thực tế. |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE | Trạng thái còn kinh doanh biến thể này. |

#### 5. Bảng `shopping_cart` & `cart_items` (Giỏ hàng & Chi tiết mục giỏ hàng)
| Tên cột | Kiểu dữ liệu | Ràng buộc | Giải thích |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Khóa chính của dòng giỏ hàng. |
| `cart_id` | UUID | NOT NULL, REFERENCES shopping_cart(id) | Giỏ hàng của người dùng tương ứng. |
| `product_variant_id` | UUID | NOT NULL, REFERENCES product_variants(id) | Biến thể sản phẩm được đưa vào giỏ. |
| `quantity` | INTEGER | NOT NULL, CHECK (quantity > 0) | Số lượng đặt mua của mục này. |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Thời điểm thêm vào giỏ. |

#### 6. Bảng `orders` & `order_items` (Đơn đặt hàng & Chi tiết đơn)
| Tên cột | Kiểu dữ liệu | Ràng buộc | Giải thích |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Mã định danh đơn hàng (GUID). |
| `user_id` | UUID | REFERENCES profiles(id) | Khách hàng thực hiện đặt đơn. |
| `status` | public.order_status | NOT NULL, DEFAULT 'pending' | Trạng thái: `pending`, `processing`, `shipped`, `delivered`, `cancelled`. |
| `total_amount` | NUMERIC(14,2) | NOT NULL, CHECK (total_amount >= 0) | Tổng giá trị đơn hàng (sau ship & giảm giá). |
| `shipping_fee` | NUMERIC(14,2) | NOT NULL, DEFAULT 0 | Phí vận chuyển hàng hóa. |
| `shipping_name` | TEXT | NOT NULL | Tên người nhận hàng. |
| `shipping_phone` | TEXT | NOT NULL | Số điện thoại nhận hàng. |
| `shipping_address` | JSONB / TEXT | NOT NULL | Địa chỉ nhận hàng chi tiết kèm tọa độ GPS. |
| `payment_method` | public.payment_method | NOT NULL, DEFAULT 'cod' | Phương thức thanh toán (`cod`, `payos`, `bank_transfer`). |
| `payment_status` | public.payment_status | NOT NULL, DEFAULT 'unpaid' | Tình trạng: `unpaid`, `paid`, `cancelled`, `expired`. |
| `payos_order_code` | BIGINT | UNIQUE, NULL | Mã định danh giao dịch đồng bộ từ Cổng PayOS. |
| `checkout_url` | TEXT | NULL | Link thanh toán PayOS dùng trong WebView. |
| `paid_at` | TIMESTAMPTZ | NULL | Thời điểm khách hàng hoàn tất thanh toán. |

---

### 3.4. New Technologies (Công nghệ mới ngoài chương trình học)

1. **Cổng thanh toán trực tuyến PayOS (Open Payment Platform):**
   * Tự động hóa hoàn toàn quy trình thanh toán không tiền mặt bằng mã QR chuẩn NAPAS 24/7.
   * Cung cấp cơ chế Webhook thời gian thực kèm xác thực mã hóa an toàn (HMAC SHA-256), giúp hệ thống tự động xác nhận đơn "Đã thanh toán" chỉ trong 2-3 giây mà không cần con người đối soát.

2. **Tích hợp Trí tuệ Nhân tạo Google Gemini AI (Generative AI):**
   * Ứng dụng Gemini 1.5 Flash thông qua API để xây dựng Chatbot tư vấn phụ kiện và đồ công nghệ tương thích với thiết bị của khách hàng.
   * Xây dựng Trợ lý phân tích thông minh cho Quản trị viên (Admin AI Analytics), tự động tổng hợp dữ liệu doanh số từ database để đưa ra câu trả lời bằng ngôn ngữ tự nhiên.

3. **Bản đồ mã nguồn mở OpenStreetMap & GPS Geolocation (`flutter_map` & `geolocator`):**
   * Giải pháp bản đồ tương tác mã nguồn mở không tốn chi phí bản quyền Google Maps API key.
   * Hỗ trợ tự động lấy vị trí hiện tại qua GPS, chuyển đổi tọa độ thành địa chỉ chi tiết (Reverse Geocoding) và trực quan hóa tuyến đường giao nhận hàng hóa (Order Tracking Map).

4. **Trực quan hóa dữ liệu kinh doanh với `fl_chart`:**
   * Thư viện vẽ biểu đồ chuyên nghiệp trên Flutter cho phép hiển thị biểu đồ đường (LineChart) và biểu đồ cột (BarChart) biểu diễn doanh thu tuần/tháng trong phân hệ Admin.

5. **Điện toán Đám mây & Docker Containerization:**
   * Toàn bộ Backend ASP.NET Core 8 được đóng gói trong Docker Container và triển khai tự động lên nền tảng đám mây Render, kết nối cơ sở dữ liệu Supabase Managed PostgreSQL.

---

## 4. Development Requirements

### 4.1. Implementation Details

* **Quản lý trạng thái (State Management):**
  * Sử dụng kiến trúc `MultiProvider` tại gốc ứng dụng (`main.dart`):
    * `AuthProvider`: Giám sát trạng thái đăng nhập, lưu trữ phiên người dùng và phân quyền `customer` / `admin`.
    * `CartProvider`: Quản lý các mục trong giỏ, hỗ trợ thêm/bớt, tính tổng số lượng (`totalQuantity`), tổng tiền (`totalAmount`) và kiểm tra tồn kho tức thời.
    * `OrderProvider`: Quản lý trạng thái luồng checkout, lưu đơn tạm, gọi API hủy đơn và cập nhật tiến trình thanh toán.
* **Xác thực đám mây (Cloud Authentication):**
  * Tích hợp `supabase_flutter` kết hợp với `google_sign_in`. Khi người dùng đăng nhập bằng Google, mã ID Token được chuyển đến Supabase Auth để cấp phát JWT an toàn mà không cần lưu mật khẩu cục bộ.
* **Tích hợp Thanh toán PayOS:**
  * Client gọi API tạo đơn thanh toán, Backend giao tiếp với PayOS SDK để sinh mã giao dịch và trả về `checkoutUrl`. Ứng dụng di động kích hoạt màn hình WebView (`webview_flutter`) để người dùng quét mã VietQR hoặc chuyển khoản trực tiếp từ app ngân hàng.
* **Bản đồ & Định vị (OpenStreetMap):**
  * Sử dụng bộ thư viện `flutter_map` kết hợp `latlong2`. Màn hình `LocationPickerScreen` cho phép người dùng kéo thả ghim trên bản đồ để chọn tọa độ chính xác, sau đó sử dụng `geocoding` để chuyển đổi sang tên đường phố cụ thể.
* **Tích hợp Trợ lý Trí tuệ Nhân tạo:**
  * Modal `CustomerAiChatModal` và `AdminAnalyticsChatModal` kết nối trực tiếp với backend `AiController.cs`, cung cấp prompt kỹ thuật kết hợp dữ liệu bảng biểu thời gian thực để tạo phản hồi chuẩn xác.

---

### 4.2. Testing

Dự án triển khai chiến lược kiểm thử toàn diện gồm cả Unit Test và Widget Test theo chuẩn Module kiểm thử chất lượng phần mềm Flutter:

#### 1. Unit Test (Kiểm thử đơn vị logic nghiệp vụ)
* **Kiểm thử Giỏ hàng (`test/unit_test.dart`):**
  * Kiểm tra hàm tính tổng số lượng và tổng tiền `totalAmount` của `CartModel`, đảm bảo các mặt hàng hết hàng (`outOfStock`) không bị tính nhầm vào tổng tiền thanh toán.
  * Kiểm tra hàm bóc tách dữ liệu JSON thuộc tính biến thể (`attributeMap`), đảm bảo giải mã chính xác các trường `color`, `ram`, `ssd`.
  * Kiểm tra hàm tiện ích định dạng tiền tệ Việt Nam `formatVnd()`, đảm bảo hiển thị đúng chuẩn phân cách hàng nghìn (VD: `25.000.000 ₫`).
* **Kiểm thử Đơn hàng (`test/order_model_test.dart` & `order_provider_test.dart`):**
  * Kiểm tra giải mã DTO phản hồi đơn hàng từ Server, kiểm tra enum trạng thái (`OrderStatusEnum`, `PaymentStatusEnum`).
  * Kiểm tra quy tắc nghiệp vụ: Đơn hàng đã thanh toán (`isPaid == true`) thì khách hàng không được phép tự ý hủy đơn (`canCancel == false`).
* **Kiểm thử Backend API (`Services.Tests/OrderServiceTests.cs`):**
  * Kiểm thử xử lý transaction trừ tồn kho kho hàng khi tạo đơn hàng.
  * Kiểm thử bộ xử lý webhook PayOS xác thực tính đúng đắn của chữ ký checksum giao dịch.

#### 2. Widget Test (Kiểm thử giao diện & tương tác người dùng)
* **Kiểm thử Component Đánh giá (`test/widget_test.dart`):**
  * Render `RatingStars` với số điểm 4.5 và 28 lượt đánh giá -> Assert tìm thấy chính xác 4 icon sao vàng (`Icons.star`), 1 icon nửa sao (`Icons.star_half`) và text `(28)`.
  * Render `RatingStars` với 0 điểm -> Assert hiển thị đúng 5 icon sao rỗng (`Icons.star_border`) và dòng chữ *"Chưa có đánh giá"*.
* **Kiểm thử Card Sản phẩm (`ProductCard`):**
  * Kiểm thử việc hiển thị đầy đủ tên sản phẩm, thương hiệu, giá tiền được định dạng đúng.
  * Giả lập sự kiện nhấn người dùng (`tester.tap()`) -> Assert callback `onTap` được kích hoạt thành công.

---

### 4.3. Deployment

* **Ứng dụng di động (Flutter Mobile Client):**
  * **Build Mode:** Release Mode tối ưu hóa mã máy và nén tài nguyên:
    ```bash
    flutter build apk --release
    ```
  * **Kết quả:** Sinh tệp `app-release.apk` tại thư mục `build/app/outputs/flutter-apk/app-release.apk` sẵn sàng cài đặt thử nghiệm trên các thiết bị Android vật lý và xuất bản lên Google Play Store.
* **Hệ thống Backend (ASP.NET Core 8 Web API):**
  * **Containerization:** Đóng gói ứng dụng thông qua `Dockerfile` đa tầng (multi-stage build) sử dụng `mcr.microsoft.com/dotnet/aspnet:8.0`.
  * **Cloud Deployment:** Triển khai tự động lên PaaS Render kết nối với Supabase PostgreSQL Database, tích hợp tự động đọc biến môi trường từ `.env` và kích hoạt Swagger UI phục vụ kiểm thử.

---

## 5. Demo of Functions (Mô tả chi tiết các chức năng)

1. **Cấu trúc Cơ sở Dữ liệu & RESTful API:**
   * Toàn bộ hệ sinh thái REST API cung cấp hơn 25 endpoints phục vụ đầy đủ các nghiệp vụ: Sản phẩm, Danh mục, Giỏ hàng, Đặt hàng, Thanh toán, Webhook và Thống kê Dashboard.
2. **Màn hình Đăng nhập & Xác thực (Login / AuthGate):**
   * Giao diện đăng nhập hiện đại hỗ trợ đăng nhập bằng Email/Password và nút đăng nhập nhanh 1 chạm bằng Google OAuth SSO, tự động điều hướng người dùng dựa theo vai trò (`customer` vào Trang chủ, `admin` vào Dashboard).
3. **Màn hình Trang chủ & Danh mục (Home Screen):**
   * Hiển thị Banner khuyến mãi dạng slider, danh sách danh mục theo biểu tượng (Chips), thanh tìm kiếm thời gian thực và lưới sản phẩm GridView 2 cột mượt mà.
4. **Màn hình Bộ lọc Sản phẩm (Product Filter Sheet):**
   * Modal bộ lọc cho phép người dùng lọc theo Khoảng giá (Price Range Slider), lọc theo Hãng sản xuất (Apple, Samsung, Sony,...) và sắp xếp theo giá tăng/giảm hoặc độ phổ biến.
5. **Màn hình Chi tiết Sản phẩm (Product Detail Screen):**
   * Hiển thị thư viện ảnh sản phẩm, thông số kỹ thuật, đánh giá sao, bảng chọn biến thể trực quan (Màu sắc, Bộ nhớ), hiển thị số lượng tồn kho và các nút tác vụ "Thêm vào giỏ", "Mua ngay".
6. **Màn hình Giỏ hàng (Cart Screen):**
   * Danh sách các sản phẩm đã chọn, hỗ trợ tăng/giảm số lượng có kiểm tra tồn kho, xóa khỏi giỏ hàng, tick chọn mua từng món và tự động tính tổng tiền thanh toán.
7. **Màn hình Thanh toán (Checkout Screen):**
   * Form điền thông tin người nhận hàng, hỗ trợ nút "Lấy vị trí hiện tại" qua GPS, chọn phương thức thanh toán (COD hoặc Chuyển khoản QR qua PayOS), xem tổng quan chi phí trước khi đặt hàng.
8. **Màn hình Chọn địa chỉ trên Bản đồ (Location Picker Screen):**
   * Bản đồ tương tác OpenStreetMap cho phép người dùng kéo ghim để xác định chính xác vị trí nhận hàng, tự động điền địa chỉ thông qua Reverse Geocoding.
9. **Cổng thanh toán Trực tuyến PayOS (PayOS WebView Screen):**
   * Nhúng trang thanh toán bảo mật của PayOS, hiển thị mã VietQR kèm số tiền chính xác, tự động đóng và điều hướng khi ngân hàng báo chuyển khoản thành công qua Webhook.
10. **Màn hình Quản lý & Theo dõi Đơn hàng (Orders & Order Tracking Map):**
    * Phân loại đơn hàng theo tab trạng thái. Màn hình chi tiết đơn hiển thị lộ trình vận chuyển hàng hóa từ kho hàng đến tay người nhận trên bản đồ sống động.
11. **Trợ lý Trí tuệ Nhân tạo Google Gemini (Customer & Admin AI Modals):**
    * Chatbot khách hàng: Hỗ trợ tư vấn chọn mua điện thoại, phụ kiện phù hợp nhu cầu.
    * Chatbot quản trị: Giải đáp câu hỏi phân tích kinh doanh, dự báo doanh thu và cảnh báo hàng tồn kho.
12. **Bảng điều khiển Quản trị viên (Admin Dashboard & Management):**
    * Thống kê KPI kinh doanh trực quan với biểu đồ doanh thu `fl_chart`, quản lý danh sách đơn hàng toàn hệ thống và giao diện CRUD cập nhật thông tin sản phẩm.

---

## 6. Conclusion and Discussion

### Pros (Ưu điểm)
* **Kiến trúc hoàn chỉnh & Thực tế:** Ứng dụng không sử dụng dữ liệu giả (Mock data) mà vận hành 100% trên nền tảng Backend ASP.NET Core 8 và Cơ sở dữ liệu PostgreSQL thực tế trên Cloud.
* **Tích hợp thanh toán số thật:** Ứng dụng tích hợp thành công Cổng PayOS với chuẩn mã QR NAPAS 24/7 của các ngân hàng Việt Nam kèm Webhook xác nhận tức thời.
* **Ứng dụng công nghệ AI tiên tiến:** Tận dụng sức mạnh của Google Gemini API để giải quyết bài toán tư vấn bán hàng tự động và phân tích số liệu quản trị.
* **Trải nghiệm bản đồ mở (OpenStreetMap):** Định vị và theo dõi lộ trình giao hàng trực quan mà không phụ thuộc vào chi phí bản quyền Google Maps đắt đỏ.
* **Bộ kiểm thử tự động phong phú:** Hệ thống bao phủ đầy đủ các tầng Unit Test logic và Widget Test giao diện theo chuẩn chất lượng phần mềm cao cấp.

### Cons (Hạn chế)
* Đòi hỏi kết nối mạng Internet liên tục để đồng bộ các tính năng thời gian thực với Cloud API.
* Do triển khai trên gói Cloud miễn phí (Render Free Tier), máy chủ Backend có thể mất từ 30-50 giây để khởi động lại (cold start) sau thời gian dài không có truy cập.

### Learning (Bài học kinh nghiệm)
* Nắm vững phương pháp quản lý trạng thái phức tạp với `Provider` (`ChangeNotifier`, `Consumer`, `Selector`) trong ứng dụng Flutter quy mô lớn.
* Thành thạo kỹ thuật tích hợp Cổng thanh toán trực tuyến Việt Nam (PayOS) và xử lý bảo mật luồng Webhook Callback.
* Nâng cao kỹ năng thiết kế cơ sở dữ liệu quan hệ, phân quyền người dùng và bảo mật hệ thống Client-Server bằng JWT Bearer Token.
* Khai thác hiệu quả Generative AI để đưa các tính năng thông minh vào ứng dụng thực tiễn.

### Future Improvements (Hướng phát triển tương lai)
* Tích hợp Firebase Cloud Messaging (FCM) để gửi thông báo đẩy (Push Notifications) khi trạng thái đơn hàng thay đổi.
* Mở rộng tính năng tìm kiếm sản phẩm bằng hình ảnh thông qua Computer Vision.
* Phát triển ứng dụng chuyên biệt dành riêng cho nhân viên giao hàng (Shipper App) để cập nhật tọa độ GPS thời gian thực liên tục lên bản đồ.

---

## 7. Contribution Table

| Topic / Task | Effort | Châu Anh Đức | Nguyễn Tiến Lộc | Trần Hữu Triết | Võ Hoàng Minh | Nguyễn Tất Thành Luân |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Case Study & Requirements Analysis** | 100% | 25% | 20% | 20% | 20% | 15% |
| **System Architecture & Database Design**| 100% | 35% | 25% | 10% | 20% | 10% |
| **Backend API & Payment / AI Integration**| 100% | 40% | 40% | 5% | 10% | 5% |
| **Mobile UI & State Management (Provider)**| 100% | 15% | 20% | 35% | 20% | 10% |
| **Admin Portal & Analytics Dashboard** | 100% | 15% | 10% | 5% | 10% | 60% |
| **Testing (Unit & Widget Tests)** | 100% | 20% | 30% | 30% | 10% | 10% |
| **Deployment (Docker, Cloud, APK Release)** | 100% | 50% | 20% | 10% | 10% | 10% |
| **Documentation & Final Report** | 100% | 20% | 20% | 20% | 20% | 20% |
| **TỔNG KẾT ĐÓNG GÓP TOÀN DỰ ÁN** | **100%** | **20%** | **20%** | **20%** | **20%** | **20%** |

---

## 8. References

1. **Flutter Official Documentation:** https://docs.flutter.dev/
2. **Provider State Management Package:** https://pub.dev/packages/provider
3. **Supabase Flutter SDK & Authentication:** https://supabase.com/docs/guides/auth
4. **PayOS Open Payment Platform Documentation:** https://payos.vn/docs/
5. **Google Gemini API Documentation:** https://ai.google.dev/docs
6. **Flutter Map (OpenStreetMap integration):** https://pub.dev/packages/flutter_map
7. **FL Chart (Data Visualization):** https://pub.dev/packages/fl_chart
8. **Microsoft .NET 8 Web API Documentation:** https://learn.microsoft.com/en-us/aspnet/core/web-api/
