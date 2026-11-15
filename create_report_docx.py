import sys
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def set_table_borders(table, color="CCCCCC", sz="4", val="single"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'  <w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'  <w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'  <w:left w:val="none"/>'
        f'  <w:right w:val="none"/>'
        f'  <w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'  <w:insideV w:val="none"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def make_callout_box(doc, text, title=""):
    tbl = doc.add_table(rows=1, cols=1)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl.autofit = False
    tbl.columns[0].width = Inches(6.5)
    cell = tbl.cell(0, 0)
    set_cell_background(cell, "F0F4F8")
    set_cell_margins(cell, top=140, bottom=140, left=200, right=160)
    
    # Left border only (accent)
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(
        f'<w:tcBorders {nsdecls("w")}>'
        f'  <w:left w:val="single" w:sz="24" w:space="0" w:color="1E3A8A"/>'
        f'  <w:top w:val="none"/>'
        f'  <w:bottom w:val="none"/>'
        f'  <w:right w:val="none"/>'
        f'</w:tcBorders>'
    )
    tcPr.append(borders)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.15
    if title:
        run_t = p.add_run(f"{title}\n")
        run_t.bold = True
        run_t.font.name = "Arial"
        run_t.font.size = Pt(10.5)
        run_t.font.color.rgb = RGBColor(0x1E, 0x3A, 0x8A)
    
    run_b = p.add_run(text)
    run_b.font.name = "Arial"
    run_b.font.size = Pt(10)
    run_b.font.color.rgb = RGBColor(0x33, 0x41, 0x55)
    
    doc.add_paragraph().paragraph_format.space_after = Pt(4)

def format_table(table, col_widths, headers, data, align_cols=None):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_borders(table, color="D1D5DB", sz="4")
    
    # Header Row
    hdr_cells = table.rows[0].cells
    for i, title in enumerate(headers):
        hdr_cells[i].width = Inches(col_widths[i])
        set_cell_background(hdr_cells[i], "1E3A8A") # Navy
        set_cell_margins(hdr_cells[i], top=120, bottom=120, left=140, right=140)
        p = hdr_cells[i].paragraphs[0]
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        if align_cols and align_cols[i] == 'C':
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        elif align_cols and align_cols[i] == 'R':
            p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        else:
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            
        run = p.add_run(title)
        run.bold = True
        run.font.name = "Arial"
        run.font.size = Pt(9.5)
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        
    # Data Rows
    for r_idx, row_data in enumerate(data):
        row_cells = table.rows[r_idx + 1].cells
        bg_color = "F8FAFC" if (r_idx % 2 == 1) else "FFFFFF"
        for c_idx, val in enumerate(row_data):
            row_cells[c_idx].width = Inches(col_widths[c_idx])
            set_cell_background(row_cells[c_idx], bg_color)
            set_cell_margins(row_cells[c_idx], top=100, bottom=100, left=140, right=140)
            p = row_cells[c_idx].paragraphs[0]
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.15
            if align_cols and align_cols[c_idx] == 'C':
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            elif align_cols and align_cols[c_idx] == 'R':
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            else:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            
            run = p.add_run(str(val))
            run.font.name = "Arial"
            run.font.size = Pt(9)
            run.font.color.rgb = RGBColor(0x1F, 0x29, 0x37)

def main():
    doc = Document()
    
    # Page Setup - Margins 1 inch
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)
        
    # Styles Setup
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Arial'
    normal_style.font.size = Pt(10.5)
    normal_style.font.color.rgb = RGBColor(0x1F, 0x29, 0x37)
    normal_style.paragraph_format.line_spacing = 1.2
    normal_style.paragraph_format.space_after = Pt(6)

    # Helper for Headings
    def add_h1(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(14)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.name = "Arial"
        run.font.size = Pt(14)
        run.font.color.rgb = RGBColor(0x1E, 0x3A, 0x8A) # Deep Navy
        return p

    def add_h2(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(10)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.name = "Arial"
        run.font.size = Pt(12)
        run.font.color.rgb = RGBColor(0x25, 0x63, 0xEB) # Royal Blue
        return p

    def add_h3(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.name = "Arial"
        run.font.size = Pt(11)
        run.font.color.rgb = RGBColor(0x0F, 0x76, 0x6E) # Teal
        return p

    def add_bullet(p_or_text, bold_prefix="", text=""):
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.15
        if bold_prefix:
            r_b = p.add_run(bold_prefix)
            r_b.bold = True
            r_b.font.name = "Arial"
            r_b.font.size = Pt(10)
            r_b.font.color.rgb = RGBColor(0x11, 0x18, 0x27)
        if text:
            r_t = p.add_run(text)
            r_t.font.name = "Arial"
            r_t.font.size = Pt(10)
            r_t.font.color.rgb = RGBColor(0x37, 0x41, 0x51)
        return p

    # ==================== COVER / HEADER ====================
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(10)
    title_p.paragraph_format.space_after = Pt(2)
    title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_t1 = title_p.add_run("TECHNICAL REPORT\n")
    r_t1.bold = True
    r_t1.font.name = "Arial"
    r_t1.font.size = Pt(20)
    r_t1.font.color.rgb = RGBColor(0x1E, 0x3A, 0x8A)

    r_t2 = title_p.add_run("MOBILE ECOMMERCE APPLICATION")
    r_t2.bold = True
    r_t2.font.name = "Arial"
    r_t2.font.size = Pt(15)
    r_t2.font.color.rgb = RGBColor(0x25, 0x63, 0xEB)

    # Subtitle Info Box
    sub_box = doc.add_table(rows=1, cols=1)
    sub_box.alignment = WD_TABLE_ALIGNMENT.CENTER
    sub_box.columns[0].width = Inches(6.5)
    c = sub_box.cell(0, 0)
    set_cell_background(c, "F8FAFC")
    set_cell_margins(c, top=100, bottom=100, left=150, right=150)
    set_table_borders(sub_box, color="CBD5E1", sz="6")
    cp = c.paragraphs[0]
    cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cp.paragraph_format.space_after = Pt(0)
    
    r_info = cp.add_run("Course: Flutter Application Development (PRM392 / Mobile Programming)\n"
                        "Project Name: TechGadget App (TechGadget E-Commerce Solution)\n"
                        "Team Size: 5 Members  |  Framework: Flutter 3.x & ASP.NET Core 8 Web API  |  Date: 2026")
    r_info.font.name = "Arial"
    r_info.font.size = Pt(9.5)
    r_info.font.color.rgb = RGBColor(0x47, 0x55, 0x69)
    r_info.italic = True

    doc.add_paragraph().paragraph_format.space_after = Pt(6)

    # ==================== 1. TEAM INTRODUCTION ====================
    add_h1("1. Team Introduction")
    p1 = doc.add_paragraph("Dự án được thực hiện bởi nhóm sinh viên với sự phân chia vai trò rõ ràng, chuyên nghiệp giữa các mảng Frontend Mobile (Flutter), Backend (.NET 8 Web API), Tích hợp Thanh toán, AI và Quản trị:")
    
    team_headers = ["STT", "Họ và Tên", "Vai trò (Role)", "Trách nhiệm chính (Responsibilities)", "Đóng góp"]
    team_widths = [0.4, 1.3, 1.2, 3.0, 0.6]
    team_align = ['C', 'L', 'L', 'L', 'C']
    team_data = [
        ["1", "Châu Anh Đức", "Team Leader & Full-Stack Architect / AI & DevOps", 
         "Thiết kế kiến trúc hệ thống tổng thể (.NET 8 Clean 3-Tier Architecture & Flutter MultiProvider). Tích hợp Supabase Auth & Google OAuth SSO. Tích hợp Google Gemini AI (Customer Chat & Admin Analytics). Đóng gói Docker và triển khai Cloud hosting (Render).", "20%"],
        ["2", "Nguyễn Tiến Lộc", "Backend & Mobile Payment / Order Specialist", 
         "Thiết kế nghiệp vụ Checkout & Quản lý đơn hàng. Tích hợp Cổng thanh toán trực tuyến PayOS (VietQR NAPAS 24/7) và xử lý bảo mật PayOS Webhook. Xây dựng màn hình Payment WebView, Order Detail và bộ Unit Tests cho Order Service / Provider.", "20%"],
        ["3", "Trần Hữu Triết", "Mobile Developer (Cart & Checkout Flow)", 
         "Xây dựng Giao diện & Logic Giỏ hàng (Cart Screen, Cart Provider, tăng/giảm số lượng, chọn món). Xây dựng màn hình Checkout Screen và màn hình thông báo đặt hàng COD thành công. Viết Unit Test cho Cart Model & Format tiền tệ VND.", "20%"],
        ["4", "Võ Hoàng Minh", "Mobile & API Developer (Product Catalog & Search)", 
         "Xây dựng API và Database cho Danh mục (Categories), Thương hiệu (Brands), Sản phẩm (Products). Thiết kế màn hình Trang chủ (HomeScreen), Product Card, Bộ lọc đa tiêu chí (Product Filter Sheet). Xây dựng màn hình Chi tiết sản phẩm (Product Detail Screen).", "20%"],
        ["5", "Nguyễn Tất Thành Luân", "Admin & Analytics Developer (Admin Portal)", 
         "Xây dựng hệ thống Quản trị viên (Admin Dashboard) với biểu đồ thống kê động qua thư viện fl_chart. Xây dựng chức năng quản lý danh mục và CRUD sản phẩm cho Admin (Add/Edit/Delete Product). Xây dựng màn hình quản lý đơn hàng (Admin Orders).", "20%"]
    ]
    t1 = doc.add_table(rows=len(team_data) + 1, cols=5)
    format_table(t1, team_widths, team_headers, team_data, team_align)

    # ==================== 2. CASE STUDY ====================
    add_h1("2. Case Study")
    add_bullet(None, "Project Title: ", "TechGadget - Giải pháp ứng dụng thương mại điện tử mua sắm thiết bị & phụ kiện công nghệ thông minh tích hợp thanh toán số PayOS và Trợ lý AI Gemini.")
    add_bullet(None, "Domain: ", "Online Sales System / Mobile E-Commerce (M-Commerce).")
    add_bullet(None, "Description: ", 
               "Trong kỷ nguyên số, nhu cầu sở hữu và nâng cấp các thiết bị công nghệ (Smartphone, Laptop, Tablet, Smartwatch, Phụ kiện âm thanh, Thiết bị thông minh) của học sinh, sinh viên và người đi làm ngày càng tăng cao. "
               "Tuy nhiên, các ứng dụng hiện nay thường cồng kềnh, thiếu tính năng hỗ trợ tư vấn tức thời và quy trình thanh toán phức tạp.\n\n"
               "TechGadget được phát triển nhằm giải quyết triệt để những khó khăn trên bằng một ứng dụng di động đa nền tảng (Flutter) mượt mà, "
               "kết hợp với hệ thống Backend ASP.NET Core 8 chuẩn công nghiệp và cơ sở dữ liệu đám mây PostgreSQL/Supabase:")
    
    make_callout_box(doc, 
                     "• Trải nghiệm mua sắm thông minh: Khám phá hàng nghìn sản phẩm chính hãng, bộ lọc thông số kỹ thuật chi tiết và hỗ trợ chọn biến thể (màu sắc, cấu hình RAM/SSD).\n"
                     "• Trợ lý AI Gemini đồng hành: Khách hàng được AI tư vấn thiết bị phù hợp với ngân sách; Quản trị viên trò chuyện với AI để truy vấn nhanh dữ liệu doanh thu, tồn kho trực tiếp từ Database.\n"
                     "• Thanh toán trực tuyến hiện đại: Tích hợp cổng thanh toán PayOS qua mã chuẩn VietQR NAPAS 24/7, xác nhận đơn hàng tự động theo thời gian thực (Webhook) và hỗ trợ phương thức COD.\n"
                     "• Bản đồ giao vận & Theo dõi hành trình: Tích hợp OpenStreetMap và GPS để định vị địa chỉ người nhận và mô phỏng lộ trình giao hàng trực quan (Order Tracking Map).",
                     title="Điểm nhấn đột phá của TechGadget")

    # ==================== 3. SYSTEM DESIGN ====================
    add_h1("3. Business Analysis / System Design")
    
    add_h2("3.1. Requirements")
    add_h3("Functional Requirements (Yêu cầu chức năng)")
    p_fn_cust = doc.add_paragraph()
    r = p_fn_cust.add_run("1. Phân hệ Khách hàng (Customer App):")
    r.bold = True
    add_bullet(None, "Xác thực người dùng: ", "Đăng ký tài khoản, đăng nhập an toàn bằng Email/Mật khẩu hoặc Google OAuth SSO; cập nhật hồ sơ cá nhân (Họ tên, SĐT, Avatar).")
    add_bullet(None, "Khám phá & Tìm kiếm sản phẩm: ", "Duyệt danh mục, thanh tìm kiếm thời gian thực, bộ lọc theo hãng, khoảng giá và sắp xếp linh hoạt.")
    add_bullet(None, "Chi tiết sản phẩm & Biến thể: ", "Xem thông số kỹ thuật, chọn biến thể (SKU, Màu sắc, Dung lượng), xem giá chênh lệch và đánh giá/nhận xét (Review & Rating Stars).")
    add_bullet(None, "Quản lý Giỏ hàng: ", "Thêm sản phẩm, điều chỉnh số lượng (kiểm tra tồn kho tức thời), tick chọn món thanh toán, tự động tính tổng tiền.")
    add_bullet(None, "Thanh toán (Checkout Flow): ", "Chọn vị trí giao hàng qua GPS/Bản đồ, chọn phương thức COD hoặc PayOS (VietQR), áp dụng ghi chú giao hàng.")
    add_bullet(None, "Cổng thanh toán PayOS: ", "Mở WebView quét mã VietQR tự động, nhận Webhook xác nhận giao dịch thành công ngay lập tức.")
    add_bullet(None, "Theo dõi Đơn hàng & Bản đồ: ", "Xem lịch sử mua sắm theo trạng thái đơn, hủy đơn khi chưa duyệt, xem lộ trình shipper giao hàng trên bản đồ thời gian thực (Order Tracking Map).")
    add_bullet(None, "Trợ lý AI Gemini: ", "Chat tương tác trực tiếp với Trợ lý AI để nhận tư vấn kỹ thuật và gợi ý thiết bị công nghệ phù hợp.")

    p_fn_adm = doc.add_paragraph()
    r = p_fn_adm.add_run("2. Phân hệ Quản trị viên (Admin Portal):")
    r.bold = True
    add_bullet(None, "Bảng điều khiển (Admin Dashboard): ", "Báo cáo KPI tổng doanh thu, số lượng đơn hàng, khách hàng mới; biểu đồ doanh thu trực quan theo ngày/tháng với fl_chart.")
    add_bullet(None, "Quản lý Danh mục & Sản phẩm: ", "Thêm mới sản phẩm, tải ảnh lên Cloud, quản lý danh sách biến thể SKU và giá, chỉnh sửa hoặc ẩn/hiện sản phẩm.")
    add_bullet(None, "Quản lý Đơn hàng: ", "Theo dõi toàn bộ đơn hàng của hệ thống, lọc trạng thái, cập nhật quy trình vận đơn (Pending -> Processing -> Shipped -> Delivered / Cancelled).")
    add_bullet(None, "Trợ lý Phân tích AI (Admin Analytics): ", "AI truy vấn trực tiếp cơ sở dữ liệu để giải đáp nhanh về doanh số, sản phẩm bán chạy và cảnh báo tồn kho.")

    add_h3("Non-functional Requirements (Yêu cầu phi chức năng)")
    add_bullet(None, "Hiệu năng (Performance): ", "Thời gian phản hồi API trung bình < 400ms. Thời gian tải dữ liệu trang chủ và chuyển màn hình trên ứng dụng < 1.5 giây.")
    add_bullet(None, "Bảo mật (Security): ", "Xác thực JWT Bearer Token mã hóa từ Supabase Auth. Cơ chế chống nâng quyền (prevent_role_escalation trigger) trong cơ sở dữ liệu. Chữ ký số HMAC_SHA256 bảo vệ Webhook thanh toán PayOS chống giả mạo.")
    add_bullet(None, "Tính khả dụng (Usability): ", "Thiết kế chuẩn Material Design 3, màu sắc hiện đại, hỗ trợ phản hồi thao tác thân thiện (Loading Skeleton, SnackBar, Alert Dialog).")
    add_bullet(None, "Tính toàn vẹn (Data Integrity): ", "Sử dụng Database Transaction cho các thao tác đặt hàng và trừ tồn kho, triệt tiêu nguy cơ bán vượt số lượng (overselling).")

    add_h2("3.2. Application Architecture")
    doc.add_paragraph("Hệ thống được thiết kế theo mô hình Client-Server phân tầng (Multi-tier Architecture) hiện đại, phân tách độc lập giữa ứng dụng di động Flutter và hệ thống Backend RESTful API:")
    
    make_callout_box(doc,
                     "[ FLUTTER CLIENT APP ]\n"
                     "  ├── UI Layer (Screens, Modals, Widgets Material 3)\n"
                     "  ├── State Management Layer (ChangeNotifierProvider: AuthProvider, CartProvider, OrderProvider)\n"
                     "  └── Data & Service Layer (Http REST Clients, Supabase Client, Geocoding Service)\n"
                     "              │  (HTTPS / JSON REST API / JWT Token)\n"
                     "              ▼\n"
                     "[ ASP.NET CORE 8 BACKEND API ]\n"
                     "  ├── API Layer (Controllers: Products, Cart, Orders, Admin, AI, PayOS Webhook)\n"
                     "  ├── Business Logic / Service Layer (OrderService, ProductService, AiGeminiService, DashboardService)\n"
                     "  ├── Data Access Layer (Repositories, Unit of Work, Entity Framework Core / Npgsql)\n"
                     "  └── External Integrations (PayOS Payment Gateway, Google Gemini API SDK)\n"
                     "              │  (PostgreSQL Connection)\n"
                     "              ▼\n"
                     "[ POSTGRESQL / SUPABASE CLOUD DATABASE ]",
                     title="Sơ đồ Kiến trúc Phân tầng Hệ thống (System Architecture)")

    add_h2("3.3. Database Design (PostgreSQL / Supabase Schema)")
    doc.add_paragraph("Cơ sở dữ liệu quan hệ được thiết kế chuẩn hóa bậc 3 (3NF) trên PostgreSQL, đảm bảo tính toàn vẹn dữ liệu và tối ưu hóa truy vấn:")

    db_widths = [1.2, 1.1, 1.6, 2.6]
    db_align = ['L', 'C', 'L', 'L']

    # Table 1: profiles
    add_h3("Bảng 1: profiles (Thông tin hồ sơ người dùng)")
    profiles_headers = ["Tên cột", "Kiểu dữ liệu", "Ràng buộc", "Giải thích"]
    profiles_data = [
        ["id", "UUID", "PRIMARY KEY, REFERENCES auth.users(id)", "Liên kết trực tiếp với tài khoản Supabase Auth."],
        ["full_name", "TEXT", "NULL", "Họ và tên hiển thị của người dùng."],
        ["avatar_url", "TEXT", "NULL", "Đường dẫn ảnh đại diện cá nhân."],
        ["phone", "TEXT", "NULL", "Số điện thoại liên hệ nhận hàng."],
        ["role", "public.user_role", "NOT NULL, DEFAULT 'customer'", "Phân quyền: 'customer' hoặc 'admin'."],
        ["created_at", "TIMESTAMPTZ", "NOT NULL, DEFAULT NOW()", "Thời điểm đăng ký tài khoản."],
        ["updated_at", "TIMESTAMPTZ", "NOT NULL, DEFAULT NOW()", "Thời điểm cập nhật thông tin gần nhất."]
    ]
    t_prof = doc.add_table(rows=len(profiles_data) + 1, cols=4)
    format_table(t_prof, db_widths, profiles_headers, profiles_data, db_align)

    # Table 2: categories
    add_h3("Bảng 2: categories (Danh mục sản phẩm)")
    categories_headers = ["Tên cột", "Kiểu dữ liệu", "Ràng buộc", "Giải thích"]
    categories_data = [
        ["id", "UUID", "PRIMARY KEY, DEFAULT uuid_generate_v4()", "Mã định danh danh mục."],
        ["name", "TEXT", "NOT NULL", "Tên danh mục (Điện thoại, Laptop, Phụ kiện,...)."],
        ["slug", "TEXT", "NOT NULL, UNIQUE", "Đường dẫn thân thiện cho danh mục."],
        ["description", "TEXT", "NULL", "Mô tả chi tiết nhóm ngành hàng."],
        ["image_url", "TEXT", "NULL", "Biểu tượng đại diện danh mục."]
    ]
    t_cat = doc.add_table(rows=len(categories_data) + 1, cols=4)
    format_table(t_cat, db_widths, categories_headers, categories_data, db_align)

    # Table 3: products
    add_h3("Bảng 3: products (Sản phẩm công nghệ)")
    products_headers = ["Tên cột", "Kiểu dữ liệu", "Ràng buộc", "Giải thích"]
    products_data = [
        ["id", "UUID", "PRIMARY KEY, DEFAULT uuid_generate_v4()", "Khóa chính sản phẩm."],
        ["category_id", "UUID", "NOT NULL, REFERENCES categories(id)", "Thuộc danh mục nào."],
        ["brand_id", "UUID", "NOT NULL, REFERENCES brands(id)", "Hãng sản xuất (Apple, Samsung, Sony,...)."],
        ["name", "TEXT", "NOT NULL", "Tên thương mại đầy đủ của sản phẩm."],
        ["slug", "TEXT", "NOT NULL, UNIQUE", "Chuỗi định danh URL duy nhất."],
        ["description", "TEXT", "NULL", "Mô tả tính năng, cấu hình chi tiết."],
        ["thumbnail_url", "TEXT", "NULL", "Link ảnh đại diện chính của sản phẩm."],
        ["base_price", "NUMERIC(14,2)", "NOT NULL, CHECK (base_price >= 0)", "Giá cơ sở khởi điểm."],
        ["is_active", "BOOLEAN", "NOT NULL, DEFAULT TRUE", "Trạng thái hiển thị mở bán."]
    ]
    t_prod = doc.add_table(rows=len(products_data) + 1, cols=4)
    format_table(t_prod, db_widths, products_headers, products_data, db_align)

    # Table 4: product_variants
    add_h3("Bảng 4: product_variants (Biến thể cấu hình & màu sắc)")
    variants_headers = ["Tên cột", "Kiểu dữ liệu", "Ràng buộc", "Giải thích"]
    variants_data = [
        ["id", "UUID", "PRIMARY KEY, DEFAULT uuid_generate_v4()", "Khóa chính của biến thể."],
        ["product_id", "UUID", "NOT NULL, REFERENCES products(id) ON DELETE CASCADE", "Sản phẩm cha sở hữu biến thể."],
        ["sku", "TEXT", "NOT NULL, UNIQUE", "Mã quản lý tồn kho duy nhất (VD: IP15PM-256-TI)."],
        ["attributes", "JSONB", "NOT NULL, DEFAULT '{}'::jsonb", "Thuộc tính biến thể (VD: {\"color\":\"Titan\",\"ram\":\"8GB\"})."],
        ["price_adjustment", "NUMERIC(14,2)", "NOT NULL, DEFAULT 0", "Mức giá chênh lệch so với giá gốc."],
        ["stock_quantity", "INTEGER", "NOT NULL, CHECK (stock_quantity >= 0)", "Số lượng hàng tồn thực tế trong kho."],
        ["is_active", "BOOLEAN", "NOT NULL, DEFAULT TRUE", "Trạng thái kinh doanh biến thể này."]
    ]
    t_var = doc.add_table(rows=len(variants_data) + 1, cols=4)
    format_table(t_var, db_widths, variants_headers, variants_data, db_align)

    # Table 5: orders
    add_h3("Bảng 5: orders (Đơn đặt hàng)")
    orders_headers = ["Tên cột", "Kiểu dữ liệu", "Ràng buộc", "Giải thích"]
    orders_data = [
        ["id", "UUID", "PRIMARY KEY, DEFAULT uuid_generate_v4()", "Mã định danh đơn hàng."],
        ["user_id", "UUID", "REFERENCES profiles(id)", "Khách hàng thực hiện đơn."],
        ["status", "public.order_status", "NOT NULL, DEFAULT 'pending'", "Trạng thái: pending, processing, shipped, delivered, cancelled."],
        ["total_amount", "NUMERIC(14,2)", "NOT NULL, CHECK (total_amount >= 0)", "Tổng giá trị thanh toán của đơn hàng."],
        ["shipping_fee", "NUMERIC(14,2)", "NOT NULL, DEFAULT 0", "Phí giao hàng."],
        ["shipping_name", "TEXT", "NOT NULL", "Họ tên người nhận."],
        ["shipping_phone", "TEXT", "NOT NULL", "Số điện thoại nhận."],
        ["shipping_address", "JSONB / TEXT", "NOT NULL", "Địa chỉ giao hàng kèm tọa độ GPS."],
        ["payment_method", "public.payment_method", "NOT NULL, DEFAULT 'cod'", "Phương thức: 'cod', 'payos', 'bank_transfer'."],
        ["payment_status", "public.payment_status", "NOT NULL, DEFAULT 'unpaid'", "Trạng thái: 'unpaid', 'paid', 'cancelled', 'expired'."],
        ["payos_order_code", "BIGINT", "UNIQUE, NULL", "Mã giao dịch đồng bộ từ Cổng PayOS."],
        ["checkout_url", "TEXT", "NULL", "Đường dẫn thanh toán PayOS dùng trong WebView."],
        ["paid_at", "TIMESTAMPTZ", "NULL", "Thời điểm hoàn tất thanh toán."]
    ]
    t_ord = doc.add_table(rows=len(orders_data) + 1, cols=4)
    format_table(t_ord, db_widths, orders_headers, orders_data, db_align)

    add_h2("3.4. New Technologies (Công nghệ mới ngoài chương trình học)")
    add_bullet(None, "Cổng thanh toán trực tuyến PayOS: ", "Tự động hóa hoàn toàn quy trình chuyển khoản qua mã QR chuẩn NAPAS 24/7 của các ngân hàng Việt Nam, xác nhận giao dịch trong 2-3s qua Secure Webhook.")
    add_bullet(None, "Trí tuệ Nhân tạo Google Gemini AI: ", "Tích hợp Gemini 1.5 Flash API phục vụ Customer AI Chatbot tư vấn sản phẩm và Admin AI Analytics phân tích dữ liệu kinh doanh trực tiếp từ database.")
    add_bullet(None, "Bản đồ tương tác OpenStreetMap (flutter_map & geolocator): ", "Bản đồ mã nguồn mở miễn phí, hỗ trợ định vị GPS tự động chuyển đổi thành địa chỉ giao hàng và vẽ tuyến đường shipper theo dõi đơn hàng.")
    add_bullet(None, "Thư viện biểu đồ fl_chart: ", "Trực quan hóa chỉ số tài chính, doanh thu theo ngày/tháng trên giao diện di động cho người quản lý.")
    add_bullet(None, "Docker & Cloud Hosting (Render & Supabase): ", "Đóng gói toàn bộ hệ thống API ASP.NET Core 8 bằng Dockerfile đa tầng và triển khai chạy thực tế trên Cloud.")

    # ==================== 4. DEVELOPMENT REQUIREMENTS ====================
    add_h1("4. Development Requirements")
    
    add_h2("4.1. Implementation Details")
    add_bullet(None, "Quản lý trạng thái (State Management): ", "Sử dụng MultiProvider bao bọc toàn bộ ứng dụng: AuthProvider (giám sát phiên và phân quyền), CartProvider (quản lý giỏ hàng, tính tổng tiền, kiểm tra tồn kho), OrderProvider (xử lý luồng đặt hàng và hủy đơn).")
    add_bullet(None, "Xác thực đám mây (Cloud Authentication): ", "Kết hợp supabase_flutter với google_sign_in. Nhận Google ID Token và xác thực qua Supabase để cấp phát JWT an toàn mà không cần quản lý mật khẩu thủ công.")
    add_bullet(None, "Thanh toán trực tuyến PayOS: ", "Gọi API Backend sinh giao dịch PayOS -> Ứng dụng mở WebView quét mã VietQR -> Webhook Backend lắng nghe thông báo ngân hàng và cập nhật trạng thái đơn thành Paid tự động.")
    add_bullet(None, "Định vị & Bản đồ (OpenStreetMap): ", "Dùng Geolocator lấy tọa độ GPS của khách hàng -> dùng Geocoding lấy địa chỉ -> dùng flutter_map vẽ pin vị trí và lộ trình giao hàng.")
    add_bullet(None, "Trợ lý Trí tuệ Nhân tạo Gemini: ", "Kết nối API Controller xử lý phân tích ngữ cảnh, truyền dữ liệu thống kê sản phẩm vào prompt để AI phản hồi chính xác.")

    add_h2("4.2. Testing")
    doc.add_paragraph("Dự án áp dụng quy trình kiểm thử tự động nghiêm ngặt bao gồm Unit Test logic và Widget Test giao diện:")
    
    add_h3("1. Unit Test (Kiểm thử logic nghiệp vụ)")
    add_bullet(None, "Kiểm thử Giỏ hàng (test/unit_test.dart): ", "Kiểm tra tính tổng số lượng (totalQuantity) và tổng tiền (totalAmount) của CartModel, đảm bảo sản phẩm hết hàng không bị tính tiền nhầm. Kiểm tra giải mã JSON thuộc tính biến thể (attributeMap) và hàm định dạng tiền tệ VND formatVnd().")
    add_bullet(None, "Kiểm thử Đơn hàng (test/order_model_test.dart & order_provider_test.dart): ", "Kiểm tra parse DTO đơn hàng, kiểm tra tính toàn vẹn của các enum trạng thái và kiểm tra quy tắc nghiệp vụ: Đơn hàng đã thanh toán (isPaid == true) thì khách hàng không được phép tự hủy đơn.")
    add_bullet(None, "Kiểm thử Backend API (Services.Tests/OrderServiceTests.cs): ", "Kiểm tra logic trừ tồn kho kho hàng khi tạo đơn hàng và kiểm tra xác thực chữ ký số Webhook PayOS.")

    add_h3("2. Widget Test (Kiểm thử giao diện & tương tác)")
    add_bullet(None, "Kiểm thử Component Đánh giá (test/widget_test.dart): ", "Kiểm tra RatingStars render đúng 4 sao vàng, 1 nửa sao và '(28)' khi có 4.5 sao; kiểm tra hiển thị đúng 5 sao rỗng và text 'Chưa có đánh giá' khi 0 sao.")
    add_bullet(None, "Kiểm thử Card Sản phẩm (ProductCard): ", "Kiểm tra render đầy đủ tên sản phẩm, thương hiệu, giá niêm yết và kích hoạt đúng callback onTap khi người dùng nhấn vào thẻ.")

    add_h2("4.3. Deployment")
    add_bullet(None, "Ứng dụng Di động (Flutter Client): ", "Biên dịch Release Mode: 'flutter build apk --release'. Tệp app-release.apk được tạo tại build/app/outputs/flutter-apk/app-release.apk sẵn sàng cài đặt trên thiết bị Android thực tế.")
    add_bullet(None, "Hệ thống Backend (ASP.NET Core 8 Web API): ", "Đóng gói Dockerfile đa tầng (mcr.microsoft.com/dotnet/aspnet:8.0), triển khai tự động lên nền tảng đám mây Render, kết nối cơ sở dữ liệu PostgreSQL Supabase và kích hoạt Swagger UI phục vụ kiểm thử API trực tuyến.")

    # ==================== 5. DEMO OF FUNCTIONS ====================
    add_h1("5. Demo of Functions")
    doc.add_paragraph("Dự án đã hoàn thiện 100% các chức năng nghiệp vụ thực tế, bao gồm:")
    add_bullet(None, "1. Cấu trúc Database & RESTful API: ", "Hệ sinh thái API hoàn chỉnh hơn 25 endpoints phục vụ đầy đủ phân hệ Customer và Admin.")
    add_bullet(None, "2. Đăng nhập & Xác thực (AuthGate): ", "Đăng nhập bằng Email/Password hoặc Google OAuth SSO 1 chạm, tự động phân luồng Customer và Admin.")
    add_bullet(None, "3. Màn hình Trang chủ (HomeScreen): ", "Banner khuyến mãi, thanh tìm kiếm từ khóa tức thời, lọc theo danh mục dạng icon chips và GridView sản phẩm.")
    add_bullet(None, "4. Màn hình Bộ lọc Nâng cao (Product Filter Sheet): ", "Lọc theo khoảng giá (Slider), lọc theo Hãng sản xuất (Apple, Samsung,...) và sắp xếp.")
    add_bullet(None, "5. Màn hình Chi tiết Sản phẩm (Product Detail Screen): ", "Xem thư viện ảnh, thông số kỹ thuật, đánh giá sao, chọn biến thể (Màu sắc, Dung lượng), hiển thị tồn kho và thêm vào giỏ.")
    add_bullet(None, "6. Màn hình Giỏ hàng (Cart Screen): ", "Tăng/giảm số lượng có kiểm tra tồn kho, xóa sản phẩm, tick chọn mua từng món và tính tổng tiền tự động.")
    add_bullet(None, "7. Màn hình Thanh toán (Checkout Screen): ", "Điền thông tin nhận hàng, nút 'Lấy vị trí GPS' tự động, chọn phương thức COD hoặc PayOS (VietQR).")
    add_bullet(None, "8. Chọn địa chỉ trên Bản đồ (Location Picker Screen): ", "Bản đồ tương tác OpenStreetMap cho phép kéo thả ghim vị trí và tự động bóc tách địa chỉ bằng Geocoding.")
    add_bullet(None, "9. Cổng thanh toán Trực tuyến PayOS: ", "Hiển thị mã QR VietQR NAPAS 24/7 trong WebView, tự động xác nhận đơn hàng qua Webhook ngay khi khách hàng chuyển khoản.")
    add_bullet(None, "10. Quản lý Đơn hàng & Theo dõi Lộ trình: ", "Quản lý đơn hàng theo từng tab trạng thái; theo dõi lộ trình shipper vận chuyển trên bản đồ trực quan (Order Tracking Map).")
    add_bullet(None, "11. Trợ lý Trí tuệ Nhân tạo Google Gemini: ", "Chatbot tư vấn chọn mua thiết bị công nghệ cho khách hàng và Chatbot phân tích doanh số, tồn kho cho người quản trị.")
    add_bullet(None, "12. Bảng điều khiển Quản trị viên (Admin Dashboard & CRUD): ", "Biểu đồ tài chính fl_chart trực quan, quản lý đơn hàng toàn hệ thống và giao diện CRUD quản trị sản phẩm.")

    # ==================== 6. CONCLUSION & DISCUSSION ====================
    add_h1("6. Conclusion and Discussion")
    add_bullet(None, "Ưu điểm (Pros): ", "Hệ thống vận hành 100% dữ liệu thật trên Backend ASP.NET Core 8 và Cloud Database. Tích hợp thanh toán trực tuyến VietQR thực tế qua PayOS. Tích hợp AI Gemini và Bản đồ OpenStreetMap sống động, giao diện Material Design 3 đẹp mắt.")
    add_bullet(None, "Hạn chế (Cons): ", "Yêu cầu kết nối mạng liên tục để đồng bộ dữ liệu Cloud. Máy chủ Render miễn phí có thể cần 30-50s khởi động lại (cold start) sau thời gian dài không có truy cập.")
    add_bullet(None, "Bài học kinh nghiệm (Learning): ", "Nắm vững kỹ thuật quản lý trạng thái nâng cao với MultiProvider trong Flutter. Nắm vững quy trình tích hợp cổng thanh toán thực tế và xử lý Webhook an toàn. Nâng cao kỹ năng thiết kế Database quan hệ và triển khai ứng dụng chuẩn công nghiệp.")
    add_bullet(None, "Hướng phát triển (Future Improvements): ", "Tích hợp Push Notification qua Firebase Cloud Messaging (FCM). Mở rộng tính năng tìm kiếm bằng giọng nói và hình ảnh. Phát triển thêm ứng dụng chuyên biệt dành riêng cho Shipper cập nhật GPS liên tục.")

    # ==================== 7. CONTRIBUTION TABLE ====================
    add_h1("7. Contribution Table")
    doc.add_paragraph("Ma trận phân bổ công việc và tỷ lệ đóng góp của từng thành viên trong nhóm:")
    
    contrib_headers = ["Hạng mục công việc (Task)", "Tổng Effort", "Châu Anh Đức", "Nguyễn Tiến Lộc", "Trần Hữu Triết", "Võ Hoàng Minh", "Nguyễn Tất Thành Luân"]
    contrib_widths = [2.2, 0.7, 0.7, 0.7, 0.7, 0.7, 0.8]
    contrib_align = ['L', 'C', 'C', 'C', 'C', 'C', 'C']
    contrib_data = [
        ["Case Study & Requirements Analysis", "100%", "25%", "20%", "20%", "20%", "15%"],
        ["System Architecture & Database Design", "100%", "35%", "25%", "10%", "20%", "10%"],
        ["Backend API & Payment / AI Integration", "100%", "40%", "40%", "5%", "10%", "5%"],
        ["Mobile UI & State Management (Provider)", "100%", "15%", "20%", "35%", "20%", "10%"],
        ["Admin Portal & Analytics Dashboard", "100%", "15%", "10%", "5%", "10%", "60%"],
        ["Testing (Unit & Widget Tests)", "100%", "20%", "30%", "30%", "10%", "10%"],
        ["Deployment (Docker, Cloud, APK Release)", "100%", "50%", "20%", "10%", "10%", "10%"],
        ["Documentation & Final Report", "100%", "20%", "20%", "20%", "20%", "20%"],
        ["TỔNG ĐÓNG GÓP TOÀN DỰ ÁN", "100%", "20%", "20%", "20%", "20%", "20%"]
    ]
    t_contrib = doc.add_table(rows=len(contrib_data) + 1, cols=7)
    format_table(t_contrib, contrib_widths, contrib_headers, contrib_data, contrib_align)

    # Highlight total row
    last_row = t_contrib.rows[-1]
    for c in last_row.cells:
        set_cell_background(c, "E2E8F0")
        for p in c.paragraphs:
            for r in p.runs:
                r.bold = True

    # ==================== 8. REFERENCES ====================
    add_h1("8. References")
    ref_list = [
        ("Flutter Official Documentation: ", "https://docs.flutter.dev/"),
        ("Provider State Management Package: ", "https://pub.dev/packages/provider"),
        ("Supabase Flutter SDK & Authentication: ", "https://supabase.com/docs/guides/auth"),
        ("PayOS Open Payment Platform Documentation: ", "https://payos.vn/docs/"),
        ("Google Gemini API Documentation: ", "https://ai.google.dev/docs"),
        ("Flutter Map (OpenStreetMap integration): ", "https://pub.dev/packages/flutter_map"),
        ("FL Chart (Data Visualization): ", "https://pub.dev/packages/fl_chart"),
        ("Microsoft .NET 8 Web API Documentation: ", "https://learn.microsoft.com/en-us/aspnet/core/web-api/")
    ]
    for title, url in ref_list:
        add_bullet(None, title, url)

    # Save document
    out_path = r"c:\Users\ANH DUC\Documents\PRJ_PRM_PRN\TECHNICAL_REPORT_TECHGADGET.docx"
    doc.save(out_path)
    print(f"Document successfully created at: {out_path}")

if __name__ == "__main__":
    main()
