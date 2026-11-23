# -*- coding: utf-8 -*-
"""
Script tạo tài liệu Word (.docx): Kịch bản Demo Từng Bước Từng Chức Năng Đồ Án WashSmart 3T
Đồ Án Tốt Nghiệp: Hệ Thống Quản Lý Dịch Vụ Giặt Ủi Thông Minh WashSmart 3T
"""

import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, hex_color):
    """Đặt màu nền cho cell trong table"""
    shading_elm = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    cell._tc.get_or_add_tcPr().append(shading_elm)

def set_cell_left_border(cell, hex_color="8A1538", sz="36"):
    """Đặt viền trái cho cell (tạo callout box)"""
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(
        f'<w:tcBorders {nsdecls("w")}>'
        f'<w:left w:val="single" w:sz="{sz}" w:space="0" w:color="{hex_color}"/>'
        f'<w:top w:val="none"/>'
        f'<w:right w:val="none"/>'
        f'<w:bottom w:val="none"/>'
        f'</w:tcBorders>'
    )
    tcPr.append(borders)

def set_table_borders(table, color="D1D5DB", sz="4"):
    """Đặt viền cho toàn bộ bảng mảnh nhẹ tinh tế"""
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'<w:top w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:bottom w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:left w:val="none"/>'
        f'<w:right w:val="none"/>'
        f'<w:insideH w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:insideV w:val="none"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def set_cell_margins(cell, top=140, bottom=140, left=180, right=180):
    """Đặt khoảng đệm lề cho cell (đơn vị dxa, 20 dxa = 1 pt)"""
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(
        f'<w:tcMar {nsdecls("w")}>'
        f'<w:top w:w="{top}" w:type="dxa"/>'
        f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
        f'<w:left w:w="{left}" w:type="dxa"/>'
        f'<w:right w:w="{right}" w:type="dxa"/>'
        f'</w:tcMar>'
    )
    tcPr.append(tcMar)

def add_callout(doc, text, title="LƯU Ý KHI TRÌNH BÀY DEMO", alert_type="note"):
    """Thêm hộp ghi chú / lưu ý nổi bật"""
    color_map = {
        "note": ("8A1538", "FDF2F4", "8A1538"),      # Đỏ mận WashSmart
        "tip": ("16A34A", "F0FDF4", "15803D"),       # Xanh lá kết quả
        "warn": ("D97706", "FFFBEB", "B45309"),      # Vàng cam lưu ý
        "info": ("2563EB", "EFF6FF", "1D4ED8")       # Xanh dương hướng dẫn
    }
    border_color, bg_color, title_color = color_map.get(alert_type, color_map["note"])
    
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    table.columns[0].width = Inches(6.5)
    
    cell = table.cell(0, 0)
    set_cell_background(cell, bg_color)
    set_cell_left_border(cell, hex_color=border_color, sz="40")
    set_cell_margins(cell, top=160, bottom=160, left=200, right=200)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.15
    run_title = p.add_run(f"📌 {title}\n")
    run_title.bold = True
    run_title.font.name = "Calibri"
    run_title.font.size = Pt(10.5)
    run_title.font.color.rgb = RGBColor.from_string(title_color)
    
    run_text = p.add_run(text)
    run_text.font.name = "Calibri"
    run_text.font.size = Pt(10)
    run_text.font.color.rgb = RGBColor(55, 65, 81)
    
    # Khoảng cách sau hộp
    p_after = doc.add_paragraph()
    p_after.paragraph_format.space_before = Pt(0)
    p_after.paragraph_format.space_after = Pt(6)

def add_step_card(doc, step_num, title, actor, screen, action, expected, speech=None):
    """Tạo thẻ hướng dẫn chi tiết từng bước demo"""
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    table.columns[0].width = Inches(6.5)
    
    cell = table.cell(0, 0)
    set_cell_background(cell, "F9FAFB")
    set_cell_left_border(cell, hex_color="8A1538", sz="32")
    set_cell_margins(cell, top=160, bottom=160, left=200, right=200)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    
    # Header bước
    r_step = p.add_run(f"BƯỚC {step_num}: {title.upper()}\n")
    r_step.bold = True
    r_step.font.name = "Calibri"
    r_step.font.size = Pt(11)
    r_step.font.color.rgb = RGBColor(138, 21, 56) # 8A1538
    
    # Meta vai trò & màn hình
    r_meta = p.add_run(f"• Vai trò: {actor}   |   • Giao diện: {screen}\n")
    r_meta.bold = True
    r_meta.font.name = "Calibri"
    r_meta.font.size = Pt(9.5)
    r_meta.font.color.rgb = RGBColor(75, 85, 99)
    
    # Thao tác
    r_act_title = p.add_run("\n▶ Thao tác thực hiện:\n")
    r_act_title.bold = True
    r_act_title.font.name = "Calibri"
    r_act_title.font.size = Pt(10)
    r_act_title.font.color.rgb = RGBColor(31, 41, 55)
    
    r_act = p.add_run(f"{action}\n")
    r_act.font.name = "Calibri"
    r_act.font.size = Pt(10)
    r_act.font.color.rgb = RGBColor(55, 65, 81)
    
    # Kết quả kỳ vọng
    r_exp_title = p.add_run("\n✔ Kết quả trên màn hình:\n")
    r_exp_title.bold = True
    r_exp_title.font.name = "Calibri"
    r_exp_title.font.size = Pt(10)
    r_exp_title.font.color.rgb = RGBColor(21, 128, 61) # 15803D
    
    r_exp = p.add_run(f"{expected}\n")
    r_exp.font.name = "Calibri"
    r_exp.font.size = Pt(10)
    r_exp.font.color.rgb = RGBColor(22, 101, 52)
    
    # Lời thoại gợi ý nếu có
    if speech:
        r_sp_title = p.add_run("\n🎤 Lời thoại thuyết trình trước Hội đồng:\n")
        r_sp_title.bold = True
        r_sp_title.italic = True
        r_sp_title.font.name = "Calibri"
        r_sp_title.font.size = Pt(9.5)
        r_sp_title.font.color.rgb = RGBColor(180, 83, 9)
        
        r_sp = p.add_run(f"\"{speech}\"")
        r_sp.italic = True
        r_sp.font.name = "Calibri"
        r_sp.font.size = Pt(9.5)
        r_sp.font.color.rgb = RGBColor(146, 64, 14)
    
    p_space = doc.add_paragraph()
    p_space.paragraph_format.space_before = Pt(0)
    p_space.paragraph_format.space_after = Pt(6)

def add_custom_table(doc, headers, data, col_widths=None):
    """Tạo bảng chuẩn chuyên nghiệp có màu header đỏ mận 3T và dòng so le"""
    table = doc.add_table(rows=len(data) + 1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_borders(table)
    
    # Header
    hdr_cells = table.rows[0].cells
    for i, title in enumerate(headers):
        hdr_cells[i].text = title
        set_cell_background(hdr_cells[i], "8A1538")
        set_cell_margins(hdr_cells[i], top=120, bottom=120, left=140, right=140)
        p = hdr_cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        for r in p.runs:
            r.font.name = "Calibri"
            r.font.size = Pt(10)
            r.font.bold = True
            r.font.color.rgb = RGBColor(255, 255, 255)
            
    # Rows
    for row_idx, row_data in enumerate(data):
        row_cells = table.rows[row_idx + 1].cells
        bg_col = "F9FAFB" if row_idx % 2 == 1 else "FFFFFF"
        for col_idx, cell_value in enumerate(row_data):
            row_cells[col_idx].text = str(cell_value)
            set_cell_background(row_cells[col_idx], bg_col)
            set_cell_margins(row_cells[col_idx], top=100, bottom=100, left=140, right=140)
            p = row_cells[col_idx].paragraphs[0]
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.15
            for r in p.runs:
                r.font.name = "Calibri"
                r.font.size = Pt(9.5)
                r.font.color.rgb = RGBColor(55, 65, 81)
                
    # Column widths
    if col_widths:
        for i, w in enumerate(col_widths):
            for row in table.rows:
                row.cells[i].width = Inches(w)
                
    p_space = doc.add_paragraph()
    p_space.paragraph_format.space_before = Pt(0)
    p_space.paragraph_format.space_after = Pt(8)
    return table

def build_document():
    doc = Document()
    
    # Cấu hình trang A4 chuẩn đồ án
    section = doc.sections[0]
    section.page_width = Inches(8.27)
    section.page_height = Inches(11.69)
    section.top_margin = Inches(0.8)
    section.bottom_margin = Inches(0.8)
    section.left_margin = Inches(0.9)
    section.right_margin = Inches(0.8)
    
    # -------------------------------------------------------------
    # TRANG BÌA (COVER PAGE)
    # -------------------------------------------------------------
    p_school = doc.add_paragraph()
    p_school.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_school.paragraph_format.space_before = Pt(10)
    p_school.paragraph_format.space_after = Pt(2)
    r1 = p_school.add_run("BỘ CÔNG THƯƠNG\n")
    r1.font.name = "Calibri"
    r1.font.size = Pt(13)
    r1.bold = True
    r2 = p_school.add_run("TRƯỜNG ĐẠI HỌC CÔNG THƯƠNG TP. HỒ CHÍ MINH (HUIT)\n")
    r2.font.name = "Calibri"
    r2.font.size = Pt(14)
    r2.bold = True
    r2.font.color.rgb = RGBColor(138, 21, 56)
    r3 = p_school.add_run("KHOA CÔNG NGHỆ THÔNG TIN\n")
    r3.font.name = "Calibri"
    r3.font.size = Pt(13)
    r3.bold = True
    r3.font.color.rgb = RGBColor(30, 58, 138)
    
    # Divider line
    p_div = doc.add_paragraph()
    p_div.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_div.paragraph_format.space_after = Pt(36)
    r_div = p_div.add_run("------------------ *** ------------------")
    r_div.font.color.rgb = RGBColor(156, 163, 175)
    
    # Title
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_title.paragraph_format.space_before = Pt(24)
    p_title.paragraph_format.space_after = Pt(12)
    p_title.paragraph_format.line_spacing = 1.25
    r_type = p_title.add_run("ĐỒ ÁN TỐT NGHIỆP ĐẠI HỌC\nNGÀNH CÔNG NGHỆ THÔNG TIN\n\n")
    r_type.font.name = "Calibri"
    r_type.font.size = Pt(16)
    r_type.bold = True
    r_type.font.color.rgb = RGBColor(55, 65, 81)
    
    r_name = p_title.add_run("HỆ THỐNG QUẢN LÝ DỊCH VỤ GIẶT ỦI THÔNG MINH\nWASHSMART 3T\n\n")
    r_name.font.name = "Calibri"
    r_name.font.size = Pt(22)
    r_name.bold = True
    r_name.font.color.rgb = RGBColor(138, 21, 56)
    
    r_sub = p_title.add_run("TÀI LIỆU HƯỚNG DẪN CHI TIẾT KỊCH BẢN DEMO\nTỪNG BƯỚC TỪNG CHỨC NĂNG HỆ THỐNG\n(DÀNH CHO BUỔI BẢO VỆ TRƯỚC HỘI ĐỒNG)")
    r_sub.font.name = "Calibri"
    r_sub.font.size = Pt(13)
    r_sub.bold = True
    r_sub.font.color.rgb = RGBColor(30, 58, 138)
    
    # Spacing
    p_space = doc.add_paragraph()
    p_space.paragraph_format.space_after = Pt(50)
    
    # Info Box Table
    info_table = doc.add_table(rows=4, cols=2)
    info_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    info_table.autofit = False
    info_data = [
        ("Sinh viên thực hiện:", "Nguyễn Thành Trung"),
        ("Chuyên ngành:", "Kỹ thuật Phần mềm / Công nghệ Thông tin"),
        ("Giảng viên hướng dẫn:", "ThS. Giảng viên Khoa CNTT - HUIT"),
        ("Thời gian thực hiện:", "Năm học 2026 - 2027")
    ]
    for idx, (k, v) in enumerate(info_data):
        c0 = info_table.rows[idx].cells[0]
        c1 = info_table.rows[idx].cells[1]
        c0.width = Inches(2.5)
        c1.width = Inches(4.0)
        c0.text = k
        c1.text = v
        p0 = c0.paragraphs[0]
        p1 = c1.paragraphs[0]
        p0.runs[0].bold = True
        p0.runs[0].font.name = "Calibri"
        p0.runs[0].font.size = Pt(11)
        p1.runs[0].bold = True
        p1.runs[0].font.name = "Calibri"
        p1.runs[0].font.size = Pt(11)
        p1.runs[0].font.color.rgb = RGBColor(138, 21, 56)
        
    p_date = doc.add_paragraph()
    p_date.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_date.paragraph_format.space_before = Pt(60)
    r_date = p_date.add_run("TP. HỒ CHÍ MINH, NĂM 2026")
    r_date.font.name = "Calibri"
    r_date.font.size = Pt(11)
    r_date.bold = True
    r_date.font.color.rgb = RGBColor(107, 114, 128)
    
    doc.add_page_break()
    
    # -------------------------------------------------------------
    # MỤC LỤC & LỜI MỞ ĐẦU
    # -------------------------------------------------------------
    p_sec = doc.add_paragraph()
    r = p_sec.add_run("LỜI MỞ ĐẦU & MỤC TIÊU TÀI LIỆU")
    r.font.name = "Calibri"
    r.font.size = Pt(16)
    r.bold = True
    r.font.color.rgb = RGBColor(138, 21, 56)
    
    p_intro = doc.add_paragraph()
    p_intro.paragraph_format.line_spacing = 1.2
    p_intro.paragraph_format.space_after = Pt(8)
    p_intro.add_run(
        "Tài liệu này được biên soạn nhằm phục vụ công tác báo cáo và thực nghiệm trực tiếp (Live Demo) "
        "đồ án tốt nghiệp Hệ Thống Quản Lý Dịch Vụ Giặt Ủi Thông Minh WashSmart 3T trước Hội đồng chấm thi. "
        "Nội dung tài liệu chuẩn hóa toàn bộ 10 phân hệ nghiệp vụ theo chu trình khép kín, "
        "từ lúc khách hàng đặt đơn giặt sấy trên ứng dụng di động, quy trình điều phối và phân công giao nhận "
        "trên bản đồ số, thao tác thực địa của Shipper (niêm phong Seal, chụp ảnh minh chứng), quản lý xử lý "
        "giặt sấy tại xưởng, xuất hóa đơn điện tử E-Invoice, giải quyết khiếu nại bồi thường 3T Care trong 60 phút, "
        "cho đến công tác đối soát nộp tiền ca trực và báo cáo doanh thu."
    )
    
    add_callout(
        doc,
        "Tài liệu cung cấp hướng dẫn 'Click-by-Click' (từng nút bấm, từng thao tác, dữ liệu mẫu nhập liệu), "
        "kèm theo kịch bản lời thoại gợi ý (Talking Points) và các mẹo trả lời câu hỏi phản biện của giảng viên. "
        "Sinh viên có thể in tài liệu này mang vào phòng hội đồng hoặc mở song song trên màn hình phụ để làm chủ 100% thời gian demo.",
        title="GIÁ TRỊ CỦA TÀI LIỆU DEMO",
        alert_type="tip"
    )
    
    # -------------------------------------------------------------
    # PHẦN 1: TỔNG QUAN KIẾN TRÚC & MÔI TRƯỜNG THỰC THI
    # -------------------------------------------------------------
    p_h1 = doc.add_paragraph()
    p_h1.paragraph_format.space_before = Pt(14)
    r = p_h1.add_run("PHẦN 1: TỔNG QUAN KIẾN TRÚC & THIẾT LẬP MÔI TRƯỜNG")
    r.font.name = "Calibri"
    r.font.size = Pt(14)
    r.bold = True
    r.font.color.rgb = RGBColor(138, 21, 56)
    
    p = doc.add_paragraph()
    p.add_run(
        "Hệ thống WashSmart 3T được xây dựng dựa trên kiến trúc phân tán hiện đại, kết nối thời gian thực (Real-time) "
        "giữa 3 phân hệ ứng dụng chính:"
    )
    
    # Bảng Ports & URLs
    ports_headers = ["Phân hệ Dịch vụ", "Công nghệ phát triển", "Địa chỉ truy cập (URL)", "Ghi chú vai trò"]
    ports_data = [
        ["Backend REST API", "C# .NET 8 Web API, EF Core", "http://localhost:5085/swagger", "Máy chủ trung tâm, quản lý Auth, Orders, Logistics, SignalR Hub"],
        ["Web Admin & Điều phối", "HTML5, TailwindCSS, Leaflet JS, OSRM", "http://localhost:5500", "Cổng thông tin cho Chủ xưởng, Quản lý, Điều phối viên & Thu ngân"],
        ["Mobile App Đa Nền Tảng", "Flutter 3.x (Web / Android / iOS)", "http://localhost:5000", "Ứng dụng cho Khách hàng đặt dịch vụ & Shipper thao tác ngoài hiện trường"]
    ]
    add_custom_table(doc, ports_headers, ports_data, [1.4, 1.8, 1.8, 1.5])
    
    # Bảng Tài khoản mẫu Demo
    p_acc = doc.add_paragraph()
    r = p_acc.add_run("Bảng Tài Khoản Kiểm Thử Đã Tích Hợp Sẵn Dữ Liệu Demo:")
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    acc_headers = ["Vai trò (Role)", "Tài khoản / Email / SĐT", "Mật khẩu", "Mục đích sử dụng Demo"]
    acc_data = [
        ["Quản trị viên (Admin)", "admin@washsmart.com", "123456", "Xem tổng quan hệ thống, doanh thu, quản lý danh mục & phân quyền"],
        ["Nhân viên Xưởng (Staff)", "0911223301 (Trần Tuyết Mai)", "123456", "Tiếp nhận đơn, cập nhật giặt sấy, kiểm định KCS, đóng gói đồ"],
        ["Nhân viên Giao nhận (Shipper)", "0818605505 (Nguyễn Thành Trung)", "123456", "Nhận đơn, xem tuyến đường, quét Seal, chụp ảnh giao, nộp tiền ca"],
        ["Khách hàng (Customer)", "0912306271 (Nguyễn Bích Phương)", "123456", "Đặt đơn mới, theo dõi trạng thái, xem hóa đơn E-Invoice, gửi khiếu nại"]
    ]
    add_custom_table(doc, acc_headers, acc_data, [1.5, 1.8, 0.9, 2.3])
    
    # Hộp khởi chạy dịch vụ
    add_callout(
        doc,
        "Trước khi bắt đầu buổi báo cáo, hãy đảm bảo cả 3 dịch vụ đều đang chạy nền:\n"
        "1. Backend API: cd WashSmart3T_Backend ; dotnet run --urls \"http://localhost:5085\"\n"
        "2. Web Admin: python WashSmart3T_Web\\dev_server.py (Cổng 5500)\n"
        "3. Flutter Mobile: cd WashSmart3T_Mobile ; flutter run -d web-server --web-port 5000\n"
        "Kiểm tra trình duyệt: Mở 2 cửa sổ song song (1 bên Web Điều phối 5500 và 1 bên Mobile 5000) để thấy rõ tính năng cập nhật thời gian thực.",
        title="LỆNH KHỞI ĐỘNG HỆ THỐNG TRƯỚC GIỜ BẢO VỆ",
        alert_type="info"
    )
    
    # -------------------------------------------------------------
    # PHẦN 2: MA TRẬN LUỒNG NGHIỆP VỤ & VÒNG ĐỜI ĐƠN HÀNG
    # -------------------------------------------------------------
    p_h1 = doc.add_paragraph()
    p_h1.paragraph_format.space_before = Pt(14)
    r = p_h1.add_run("PHẦN 2: MA TRẬN LUỒNG NGHIỆP VỤ & VÒNG ĐỜI ĐƠN HÀNG")
    r.font.name = "Calibri"
    r.font.size = Pt(14)
    r.bold = True
    r.font.color.rgb = RGBColor(138, 21, 56)
    
    p = doc.add_paragraph()
    p.add_run(
        "Mỗi đơn hàng trong hệ thống WashSmart 3T được vận hành qua một cỗ máy trạng thái hữu hạn (State Machine) "
        "chặt chẽ gồm 8 trạng thái liên tục, phản ánh đúng chu trình xử lý giặt ủi công nghiệp hiện đại:"
    )
    
    lifecycle_headers = ["Mã trạng thái", "Tên hiển thị", "Phân hệ chịu trách nhiệm", "Hành động nghiệp vụ tương ứng"]
    lifecycle_data = [
        ["Pending", "Chờ tiếp nhận", "Mobile Khách hàng", "Khách gửi đơn thành công, chờ xưởng xác nhận đơn"],
        ["Confirmed", "Đã xác nhận", "Web Admin / Staff", "Xưởng duyệt đơn, gán mã Seal dự kiến, chuẩn bị điều phối"],
        ["PickingUp", "Đang lấy đồ", "Mobile Shipper", "Shipper nhận nhiệm vụ, bật GPS dẫn đường tới địa chỉ khách"],
        ["Received", "Đã nhận đồ", "Mobile Shipper", "Shipper cân đo, bấm seal niêm phong, chụp ảnh mã Seal tải lên"],
        ["Washing", "Đang giặt", "Web Xưởng giặt", "Xưởng đối chiếu seal, đưa đồ vào máy giặt sấy theo quy trình"],
        ["Washed", "Đã giặt xong", "Web Xưởng giặt", "KCS kiểm tra chất lượng, ủi hơi nước, đóng túi sạch chuyên dụng"],
        ["Delivering", "Đang giao hàng", "Mobile Shipper", "Shipper nhận túi sạch từ xưởng, di chuyển giao tận tay khách"],
        ["Completed", "Đã hoàn thành", "Mobile Shipper", "Shipper chụp ảnh bàn giao thực tế, thu tiền COD/chuyển khoản, xuất Hóa đơn điện tử"]
    ]
    add_custom_table(doc, lifecycle_headers, lifecycle_data, [1.2, 1.4, 1.4, 2.5])
    
    doc.add_page_break()
    
    # -------------------------------------------------------------
    # PHẦN 3: KỊCH BẢN DEMO CHI TIẾT TỪNG BƯỚC (10 KỊCH BẢN)
    # -------------------------------------------------------------
    p_h1 = doc.add_paragraph()
    r = p_h1.add_run("PHẦN 3: KỊCH BẢN DEMO CHI TIẾT 10 PHÂN HỆ NGHIỆP VỤ")
    r.font.name = "Calibri"
    r.font.size = Pt(15)
    r.bold = True
    r.font.color.rgb = RGBColor(138, 21, 56)
    
    p_sub = doc.add_paragraph()
    p_sub.add_run(
        "Phần này mô tả chi tiết quy trình demo từ bước 1 đến bước 10 theo đúng trình tự thực tế. "
        "Mỗi kịch bản đều bao gồm: Vai trò, Màn hình, Thao tác bấm nút, Kết quả trên màn hình và Lời thoại gợi ý."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 1: ĐẶT ĐƠN HÀNG DỊCH VỤ (MOBILE APP)
    # -------------------------------------------------------------
    p_sc1 = doc.add_paragraph()
    p_sc1.paragraph_format.space_before = Pt(12)
    r = p_sc1.add_run("KỊCH BẢN 1: KHÁCH HÀNG ĐẶT ĐƠN DỊCH VỤ GIẶT ỦI THÔNG MINH")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="1.1",
        title="Khách hàng đăng nhập ứng dụng Mobile",
        actor="Khách hàng (Customer)",
        screen="Mobile App (http://localhost:5000/#/login)",
        action="1. Nhập Số điện thoại: 0912306271\n2. Nhập Mật khẩu: 123456\n3. Bấm nút 'Đăng nhập'.",
        expected="Chuyển đến Màn hình chính (Home Screen) hiển thị lời chào 'Chào bạn, Nguyễn Bích Phương!', số dư điểm thưởng (120 WashPoints), banner khuyến mãi và các dịch vụ nổi bật.",
        speech="Kính thưa Hội đồng, em xin bắt đầu kịch bản với góc nhìn của Khách hàng. Khách hàng mở ứng dụng di động WashSmart 3T và đăng nhập bằng số điện thoại. Ứng dụng tích hợp công nghệ JWT Token và ghi nhớ phiên đăng nhập an toàn."
    )
    
    add_step_card(
        doc,
        step_num="1.2",
        title="Chọn dịch vụ giặt ủi và các gói chăm sóc cao cấp 3T Care",
        actor="Khách hàng (Customer)",
        screen="Mobile App (Trang Đặt Dịch Vụ - Booking Screen)",
        action="1. Tại thanh điều hướng đáy, chọn tab 'Đặt lịch' (biểu tượng máy giặt).\n"
               "2. Chọn dịch vụ: 'Giặt hấp comple / áo vest' (Đơn giá 80.000đ/bộ, số lượng: 1).\n"
               "3. Tích chọn tiện ích nâng cao: 'Ủi hơi nước chống nhăn form' (+20.000đ).\n"
               "4. Tích chọn hương thơm: 'Hương Hoa Ban Mai 3T' (Miễn phí 0đ).\n"
               "5. Nhập ghi chú đặc biệt: 'Vải mỏng cần giặt nhiệt dịu 55 độ C, bấm mã seal niêm phong trước mặt khi nhận đồ'.",
        expected="Hệ thống tự động cộng dồn chi phí: Tiền dịch vụ 80.000đ + Phụ phí ủi hơi nước 20.000đ = Tạm tính 100.000đ. Phí vận chuyển tiêu chuẩn hiển thị 30.000đ.",
        speech="Điểm đặc sắc của WashSmart 3T là khách hàng có thể chọn chính xác từng dịch vụ cao cấp và các gói chăm sóc sợi vải như ủi hơi nước form phẳng hoặc chọn hương thơm theo sở thích cá nhân."
    )
    
    add_step_card(
        doc,
        step_num="1.3",
        title="Chọn địa chỉ, hẹn giờ giao nhận và áp mã giảm giá",
        actor="Khách hàng (Customer)",
        screen="Mobile App (Booking Screen - Phần Lộ trình & Thanh toán)",
        action="1. Địa chỉ lấy & giao hàng: Nhập '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP.HCM'.\n"
               "2. Khung giờ hẹn shipper tới lấy đồ: Chọn 'Hôm nay (08:00 - 10:00)'.\n"
               "3. Tại ô 'Mã giảm giá (Voucher)': Nhập mã '3TCHAOBAN' và bấm 'Áp dụng'.\n"
               "4. Chọn hình thức thanh toán: Chọn 'Chuyển khoản ngân hàng (VietQR / Chuyển khoản)'.\n"
               "5. Bấm nút đỏ lớn 'Xác nhận Đặt Đơn'.",
        expected="Hệ thống áp dụng giảm trực tiếp -20.000đ. Tổng thanh toán cuối cùng: 80k + 20k + 30k (ship) - 20k (voucher) = 110.000đ. Pop-up thông báo thành công xuất hiện với mã đơn hàng tự động sinh (ví dụ #WS3T-0045) và mã Seal dự kiến WS-SEAL-0045.",
        speech="Sau khi áp dụng mã voucher '3TCHAOBAN', khách hàng bấm Đặt đơn. Đơn hàng ngay lập tức được gửi lên Backend API và phát tín hiệu Real-time tới cổng quản trị của xưởng giặt."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 2: TIẾP NHẬN & XÁC NHẬN ĐƠN (WEB ADMIN)
    # -------------------------------------------------------------
    p_sc2 = doc.add_paragraph()
    p_sc2.paragraph_format.space_before = Pt(12)
    r = p_sc2.add_run("KỊCH BẢN 2: TIẾP NHẬN & DUYỆT ĐƠN TẠI QUẦY QUẢN TRỊ (WEB ADMIN)")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="2.1",
        title="Quản trị viên đăng nhập & Xem danh sách đơn mới",
        actor="Quản trị viên / Nhân viên (Admin / Staff)",
        screen="Web Admin (http://localhost:5500/login.html -> orders.html)",
        action="1. Đăng nhập Email: admin@washsmart.com / Mật khẩu: 123456.\n"
               "2. Truy cập menu 'Quản lý đơn hàng' (orders.html).\n"
               "3. Nhấp vào tab 'Chờ tiếp nhận' (Pending).",
        expected="Đơn hàng #WS3T-0045 vừa tạo xuất hiện ở đầu bảng với biểu tượng nhấp nháy 'Mới tạo', hiển thị đầy đủ tên khách hàng 'Nguyễn Bích Phương', số điện thoại, giá tiền 110.000đ và địa chỉ 140 Lê Trọng Tấn.",
        speech="Bây giờ em chuyển sang phân hệ Web Quản trị. Quản lý xưởng giặt thấy ngay đơn hàng mới xuất hiện trên bảng giám sát thời gian thực mà không cần tải lại trang."
    )
    
    add_step_card(
        doc,
        step_num="2.2",
        title="Xem chi tiết đơn, duyệt đơn & In tem bill niêm phong",
        actor="Quản trị viên / Nhân viên (Admin / Staff)",
        screen="Web Admin (Modal Chi tiết đơn hàng - orders.html)",
        action="1. Bấm nút 'Chi tiết' (hoặc mã đơn #WS3T-0045).\n"
               "2. Kiểm tra thông tin giặt: 1 bộ comple/áo vest + ủi hơi nước + hương hoa ban mai.\n"
               "3. Bấm nút xanh 'Xác nhận đơn hàng'.\n"
               "4. Bấm nút 'In Phiếu Gửi / Tem Bill'.",
        expected="Trạng thái đơn hàng chuyển thành 'Confirmed' (Đã xác nhận). Cửa sổ in mở ra phiếu tiếp nhận chứa Mã vạch (Barcode), Mã QR thanh toán VietQR và Mã Seal niêm phong để chuẩn bị giao cho Shipper.",
        speech="Xưởng giặt xác nhận nhận đơn và có thể in tem nhãn đính kèm túi đồ. Ngay sau đó, đơn hàng sẵn sàng chuyển sang bước điều phối tuyến đường cho Shipper."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 3: BẢN ĐỒ SỐ ĐIỀU PHỐI TUYẾN ĐƯỜNG (WEB DISPATCH)
    # -------------------------------------------------------------
    p_sc3 = doc.add_paragraph()
    p_sc3.paragraph_format.space_before = Pt(12)
    r = p_sc3.add_run("KỊCH BẢN 3: BẢN ĐỒ SỐ ĐIỀU PHỐI & GIÁM SÁT SHIPPER TRỰC TUYẾN")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="3.1",
        title="Mở Trung tâm Điều phối Bản đồ số & Giám sát Shipper",
        actor="Điều phối viên (Dispatcher)",
        screen="Web Admin (http://localhost:5500/dispatch.html)",
        action="1. Trên thanh điều hướng Web, bấm menu 'Điều phối & Lộ trình' (dispatch.html).\n"
               "2. Bấm nút 'Xem Bản Đồ Toàn Cảnh'.",
        expected="Bản đồ số OpenStreetMap / Leaflet hiển thị trực quan toàn bộ khu vực TP.HCM. Điểm trung tâm Hub 3T (140 Lê Trọng Tấn) có biểu tượng vòng tròn đỏ thương hiệu. Biểu tượng xe máy của Shipper Nguyễn Thành Trung đỗ sẵn ngay tại Cửa hàng với trạng thái xanh 'Trực tuyến'. Các shipper Offline tự động được ẩn hoàn toàn để không gây nhầm lẫn.",
        speech="Đây là màn hình Bản đồ số Điều phối Tuyến đường. Điểm cốt lõi được cải tiến: Shipper là nhân viên chính thức của xưởng giặt nên vị trí xuất phát luôn đỗ tại Hub 140 Lê Trọng Tấn. Hệ thống chỉ hiển thị các Shipper đang mở ca trực tuyến (Online)."
    )
    
    add_step_card(
        doc,
        step_num="3.2",
        title="Chọn đơn hàng, tính toán cự ly OSRM và phân công cho Shipper",
        actor="Điều phối viên (Dispatcher)",
        screen="Web Admin (dispatch.html - Modal Bản đồ)",
        action="1. Trong danh sách đơn cần điều phối bên cột trái, tích chọn đơn hàng #WS3T-0045.\n"
               "2. Xem trên bản đồ: Tuyến đường màu xanh ngọc nối từ Xưởng đến nhà khách hàng được tự động vẽ bằng công cụ định tuyến OSRM Driving Engine.\n"
               "3. Tại ô 'Gán lộ trình cho Shipper': Chọn 'Shipper Nguyễn Thành Trung'.\n"
               "4. Bấm nút đỏ 'Xác nhận Gán Đơn Cho Shipper'.",
        expected="Hệ thống tính toán HUD: Cự ly tuyến đường, thời gian di chuyển dự kiến. Sau khi bấm xác nhận, đơn hàng được gán thành công cho Shipper Nguyễn Thành Trung. Trạng thái phân công cập nhật tức thì trên cơ sở dữ liệu.",
        speech="Người điều phối chỉ cần chọn đơn và chọn shipper trực ca. Hệ thống tự động tính toán lộ trình đường bộ thực tế qua OSRM Engine và truyền lệnh trực tiếp đến điện thoại của Shipper."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 4: SHIPPER NHẬN ĐƠN & NIÊM PHONG SEAL (MOBILE)
    # -------------------------------------------------------------
    p_sc4 = doc.add_paragraph()
    p_sc4.paragraph_format.space_before = Pt(12)
    r = p_sc4.add_run("KỊCH BẢN 4: SHIPPER LẤY ĐỒ, DẪN ĐƯỜNG & NIÊM PHONG SEAL MINH BẠCH")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="4.1",
        title="Shipper kiểm tra tuyến đường & Mở dẫn đường Google Maps",
        actor="Nhân viên Giao nhận (Shipper)",
        screen="Mobile App (http://localhost:5000/#/shipper)",
        action="1. Đăng nhập tài khoản Shipper: 0818605505 / Mật khẩu: 123456.\n"
               "2. Kiểm tra thanh trên cùng: Đang ở chế độ 'Trực tuyến' (chấm xanh lá).\n"
               "3. Tại tab 'Cần lấy', đơn hàng #WS3T-0045 xuất hiện.\n"
               "4. Bấm nút 'Xem tuyến' trên thanh lộ trình hôm nay để xem bản đồ Leaflet nhúng các trạm dừng.\n"
               "5. Bấm nút 'Dẫn đường Google Maps' trên thẻ đơn hàng.",
        expected="Ứng dụng mở giao diện bản đồ tuyến đường tương tác và tự động tạo liên kết mở ứng dụng Google Maps với tọa độ chính xác của khách hàng, giúp shipper lái xe an toàn và nhanh nhất.",
        speech="Shipper mở ứng dụng trên điện thoại, thấy ngay đơn hàng cần lấy trong ca trực. Shipper có thể xem bản đồ lộ trình các trạm dừng và bấm nút để mở Google Maps dẫn đường từng ngã rẽ."
    )
    
    add_step_card(
        doc,
        step_num="4.2",
        title="Shipper đến nơi, cân đồ và chụp ảnh Mã Seal niêm phong",
        actor="Nhân viên Giao nhận (Shipper)",
        screen="Mobile App (Màn hình Shipper - Thao tác nhận đồ)",
        action="1. Khi đến nhà khách, shipper bấm 'Bắt đầu lấy đồ' -> Trạng thái chuyển 'PickingUp'.\n"
               "2. Shipper cùng khách hàng kiểm tra quần áo comple/áo vest, kiểm tra túi áo và thực hiện cân đồ.\n"
               "3. Cho đồ vào túi chuyên dụng và bấm dây Seal niêm phong mang mã 'WS-SEAL-0045'.\n"
               "4. Bấm nút 'Chụp ảnh Seal niêm phong' -> Chọn ảnh thật từ thiết bị/camera.\n"
               "5. Bấm nút xanh 'Xác nhận đã nhận đồ & Niêm phong'.",
        expected="Ảnh chụp thực tế của tem niêm phong Seal được tải lên máy chủ API. Trạng thái đơn hàng chuyển sang 'Received' (Đã nhận đồ). Khách hàng trên app của mình ngay lập tức xem được ảnh mã Seal này để đối soát.",
        speech="Đây là tính năng độc quyền tạo nên sự an tâm tuyệt đối cho khách hàng: Quy trình niêm phong Seal 3T Care. Shipper chụp ảnh chiếc tem seal đã khóa trước mặt khách và đẩy lên hệ thống. Không ai có thể mở túi đồ tráo đổi trên đường vận chuyển."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 5: XỬ LÝ GIẶT SẤY TẠI XƯỞNG (WEB STAFF)
    # -------------------------------------------------------------
    p_sc5 = doc.add_paragraph()
    p_sc5.paragraph_format.space_before = Pt(12)
    r = p_sc5.add_run("KỊCH BẢN 5: XỬ LÝ GIẶT ỦI, KCS & ĐÓNG GÓI TẠI XƯỞNG")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="5.1",
        title="Xưởng nhận đồ, đối chiếu mã Seal & Chuyển sang Đang giặt",
        actor="Nhân viên Xưởng (Staff)",
        screen="Web Admin (orders.html - Tab 'Đã nhận đồ')",
        action="1. Nhân viên xưởng mở tab 'Đã nhận đồ' (Received).\n"
               "2. Kiểm tra mã Seal trên túi đồ thực tế trùng khớp với mã WS-SEAL-0045 trên hệ thống.\n"
               "3. Cắt seal, đưa đồ vào lồng giặt riêng biệt (chế độ giặt khô hấp mềm 55 độ C cho vest).\n"
               "4. Bấm nút 'Bắt đầu giặt'.",
        expected="Trạng thái đơn hàng chuyển thành 'Washing' (Đang giặt). Trên app khách hàng hiển thị thông báo: 'Đồ của bạn đang được giặt hấp chuyên sâu tại xưởng 3T'.",
        speech="Khi shipper chở đồ về xưởng, nhân viên tiếp nhận đối chiếu mã seal rồi mới cắt seal đưa vào lồng giặt. Thao tác 'Bắt đầu giặt' giúp khách hàng theo dõi sát sao tiến độ món đồ của mình."
    )
    
    add_step_card(
        doc,
        step_num="5.2",
        title="Kiểm định chất lượng KCS, ủi hơi nước & Đóng gói hoàn tất",
        actor="Nhân viên Xưởng (Staff)",
        screen="Web Admin (orders.html - Chi tiết đơn)",
        action="1. Sau chu trình giặt hấp và sấy dịu, nhân viên thực hiện ủi hơi nước chống nhăn giữ form theo đúng yêu cầu gói cộng thêm của khách.\n"
               "2. Xịt dưỡng tinh dầu Hương Hoa Ban Mai 3T.\n"
               "3. Lồng túi áo trùm chống bụi cao cấp, dán tem mã giao hàng #WS3T-0045.\n"
               "4. Bấm nút 'Đã giặt xong & Đóng gói'.",
        expected="Trạng thái đơn chuyển sang 'Washed' (Đã giặt xong). Đơn hàng tự động được đẩy sang danh sách hàng sẵn sàng xuất xưởng cho Shipper đi giao.",
        speech="Xưởng hoàn tất quy trình KCS, ủi hơi nước và đóng gói sạch sẽ. Đơn hàng chuyển sang trạng thái Washed và tự động thông báo cho Shipper đến lấy hàng giao trả."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 6: SHIPPER GIAO HÀNG & CHỤP ẢNH MINH CHỨNG (MOBILE)
    # -------------------------------------------------------------
    p_sc6 = doc.add_paragraph()
    p_sc6.paragraph_format.space_before = Pt(12)
    r = p_sc6.add_run("KỊCH BẢN 6: SHIPPER GIAO TRẢ ĐỒ & CHỤP ẢNH MINH CHỨNG TẬN TAY")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="6.1",
        title="Shipper nhận túi đồ sạch và bắt đầu di chuyển giao",
        actor="Nhân viên Giao nhận (Shipper)",
        screen="Mobile App (http://localhost:5000/#/shipper - Tab 'Cần giao')",
        action="1. Shipper mở tab 'Cần giao' (Delivering).\n"
               "2. Thấy đơn hàng #WS3T-0045 xuất hiện với nhãn 'Giao hàng tận tay'.\n"
               "3. Bấm nút 'Bắt đầu giao' -> Trạng thái đơn chuyển sang 'Delivering'.\n"
               "4. Shipper di chuyển đến địa chỉ khách hàng (140 Lê Trọng Tấn).",
        expected="Trên ứng dụng của khách hàng hiển thị thông báo Shipper đang trên đường giao hàng tới bạn.",
        speech="Shipper nhận túi đồ sạch từ xưởng, chuyển đơn sang trạng thái Đang giao hàng và lái xe đến giao trả cho khách."
    )
    
    add_step_card(
        doc,
        step_num="6.2",
        title="Chụp ảnh minh chứng giao hàng & Hoàn tất đơn",
        actor="Nhân viên Giao nhận (Shipper)",
        screen="Mobile App (Popup Xác nhận giao hàng)",
        action="1. Đến nơi, trao túi đồ sạch cho khách.\n"
               "2. Shipper bấm nút 'Xác nhận giao hàng'.\n"
               "3. Popup yêu cầu tải ảnh minh chứng: Shipper bấm vào khung ảnh và tải ảnh chụp thật cảnh bàn giao đồ giặt sạch cho khách hàng.\n"
               "4. Kiểm tra trạng thái thanh toán: Đơn đã thanh toán chuyển khoản trước (0đ COD) hoặc nếu tiền mặt thì thu tiền và tích 'Đã thu tiền COD'.\n"
               "5. Bấm nút xanh 'Xác nhận đã giao hàng'.",
        expected="Ảnh chụp giao hàng thật được lưu lên hệ thống. Trạng thái đơn hàng chính thức chuyển sang 'Completed' (Đã hoàn thành). Đơn hàng tự động dời sang tab 'Đã hoàn tất'.",
        speech="Để chấm dứt hoàn toàn tình trạng thất lạc hoặc khách báo chưa nhận đồ, Shipper bắt buộc phải chụp ảnh minh chứng thực tế khi trao túi đồ cho khách. Sau khi xác nhận, đơn hàng chính thức hoàn tất."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 7: KHÁCH HÀNG XEM HÓA ĐƠN ĐIỆN TỬ & TÍCH ĐIỂM
    # -------------------------------------------------------------
    p_sc7 = doc.add_paragraph()
    p_sc7.paragraph_format.space_before = Pt(12)
    r = p_sc7.add_run("KỊCH BẢN 7: KHÁCH HÀNG XEM MINH CHỨNG, HÓA ĐƠN ĐIỆN TỬ & TÍCH ĐIỂM")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="7.1",
        title="Khách hàng xem lại đơn hàng & Bộ đôi ảnh minh chứng đối soát",
        actor="Khách hàng (Customer)",
        screen="Mobile App (orders_screen.dart -> Chi tiết Theo dõi đơn hàng)",
        action="1. Khách hàng vào tab 'Đơn hàng' -> Chọn đơn hàng vừa hoàn tất #WS3T-0045.\n"
               "2. Cuộn xem khu vực 'Ảnh Xác Nhận Minh Chứng (2 ảnh)':\n"
               "   - Ảnh 1: Ảnh chụp mã Seal khi shipper lấy đồ tại nhà.\n"
               "   - Ảnh 2: Ảnh chụp bàn giao túi đồ sạch khi giao hoàn tất.",
        expected="Hiển thị song song 2 ảnh minh chứng rõ nét. Khách hàng có thể bấm vào ảnh để phóng to kiểm tra mã seal và túi đồ.",
        speech="Khách hàng mở chi tiết đơn hàng đã hoàn tất. Cả khách hàng và quản lý đều có thể xem lại 2 tấm ảnh minh chứng thực tế: ảnh seal niêm phong ban đầu và ảnh giao hàng lúc sau, đảm bảo 100% minh bạch."
    )
    
    add_step_card(
        doc,
        step_num="7.2",
        title="Xem Hóa đơn điện tử E-Invoice & Điểm thưởng tích lũy",
        actor="Khách hàng (Customer)",
        screen="Mobile App (Đáy màn hình Theo dõi đơn hàng)",
        action="1. Quan sát khu vực dưới cùng của màn hình chi tiết đơn hàng:\n"
               "   - Khối màu xanh ngọc: 'Hóa Đơn Điện Tử 3T (E-INVOICE)'.\n"
               "   - Số hóa đơn: HD-WS3T-0045.\n"
               "   - Số tiền thanh toán: 110.000đ | Hình thức: BankTransfer.\n"
               "   - Điểm tích lũy: '+11 WashPoints tích lũy'.\n"
               "2. Bấm nút 'Xem Chi Tiết Hóa Đơn Điện Tử (E-Receipt)' để xem biên lai dạng hóa đơn bán lẻ hoàn chỉnh.",
        expected="Hiển thị hóa đơn điện tử chuẩn nghiệp vụ gồm: Mã số thuế, ngày giờ lập hóa đơn, chi tiết đơn giá, tiền công giặt, phụ phí ủi, tiền chiết khấu voucher và mã QR xác thực. Số dư điểm của khách hàng được cộng thêm 11 điểm (tỷ lệ 10%). Lịch sử trạng thái đơn được ẩn gọn gàng theo đúng tiêu chuẩn giao diện hoàn thành.",
        speech="Phía dưới cùng của đơn hàng là khối Hóa đơn điện tử E-Invoice chuyên nghiệp, ghi nhận chi tiết thanh toán và điểm thưởng WashPoints. Khách hàng có thể mở E-Receipt điện tử để lưu trữ hoặc xuất trình thanh toán chi phí công tác."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 8: BẢO HIỂM 3T CARE & KHIẾU NẠI ĐỀN BÙ
    # -------------------------------------------------------------
    p_sc8 = doc.add_paragraph()
    p_sc8.paragraph_format.space_before = Pt(12)
    r = p_sc8.add_run("KỊCH BẢN 8: CHÍNH SÁCH BẢO HIỂM 3T CARE & KHIẾU NẠI ĐỀN BÙ 60 PHÚT")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="8.1",
        title="Khách hàng gửi khiếu nại & Tải ảnh hỏng thật từ di động",
        actor="Khách hàng (Customer)",
        screen="Mobile App (complaint_screen.dart)",
        action="1. Trong màn hình Theo dõi đơn #WS3T-0045, bấm nút đỏ 'Gửi Khiếu Nại Đơn Hàng Này' (trong khối Bảo hiểm 3T Care & Bồi thường).\n"
               "2. Lưu ý kiểm tra thời hạn: Nút này chỉ khả dụng trong vòng 60 phút sau khi đơn giao thành công; sau 60 phút nút sẽ tự động khóa lại.\n"
               "3. Tại Mục 1: Chọn món đồ bị sự cố -> Tích chọn '1 bộ Giặt hấp comple / áo vest'.\n"
               "4. Tại Mục 2: Phân loại sự cố -> Bấm chọn 'Vết bẩn chưa sạch hoàn toàn' (hoặc Lem màu / Rách sứt nút).\n"
               "5. Tại Mục 3: Tải ảnh bằng chứng -> Bấm '+ Thêm ảnh' và tải ảnh chụp thật vết bẩn trên áo từ thư viện ảnh điện thoại lên.\n"
               "6. Tại Mục 4: Nhập mô tả: 'Ve áo bên trái còn vết cà phê mờ, nhờ xưởng giặt tẩy lại giúp'.\n"
               "7. Tại Mục 5: Chọn giải pháp mong muốn -> Tích chọn 'Giặt & tẩy hấp phục hồi miễn phí trong 24h' (hoặc Hoàn tiền cước / Đền bù 100%).\n"
               "8. Bấm nút đỏ lớn 'Gửi khiếu nại & Yêu cầu xử lý'.",
        expected="Hệ thống gửi dữ liệu lên máy chủ API ComplaintsController. Pop-up thông báo thành công: 'Yêu cầu khiếu nại đã được ghi nhận. Cam kết phản hồi trong 2 giờ làm việc'.",
        speech="Đây là tính năng Bảo hiểm 3T Care độc đáo nhằm cam kết chất lượng. Khách hàng có 60 phút sau khi nhận đồ để kiểm tra. Nếu có vấn đề, khách hàng chụp ảnh thật từ điện thoại tải lên, chọn đúng món đồ và chọn hướng giải quyết. Sau 60 phút, hệ thống tự động chốt để tránh gian lận."
    )
    
    add_step_card(
        doc,
        step_num="8.2",
        title="Quản trị viên tiếp nhận khiếu nại & Phê duyệt phương án đền bù",
        actor="Quản trị viên (Admin)",
        screen="Web Admin (orders.html / Modal Xử lý khiếu nại)",
        action="1. Quản lý mở Web Admin, xuất hiện thông báo khẩn cấp có khiếu nại mới của đơn #WS3T-0045.\n"
               "2. Bấm xem chi tiết khiếu nại: Mở ảnh chụp thật vết bẩn của khách, đối chiếu với ảnh chụp Seal lúc lấy đồ của Shipper.\n"
               "3. Bấm nút 'Chấp nhận bồi thường' -> Chọn phương án: 'Tạo đơn giặt lại miễn phí mã #WS3T-RE0045' và cấp voucher xin lỗi 50.000đ.",
        expected="Yêu cầu khiếu nại được đóng với trạng thái 'Resolved' (Đã giải quyết). Khách hàng nhận được thông báo xin lỗi và mã voucher bồi thường ngay trong ví ưu đãi trên app.",
        speech="Trên Web Admin, ban quản lý nhìn thấy ảnh thực tế khách chụp, đối chiếu với ảnh seal ban đầu để thẩm định và bấm duyệt đền bù chỉ bằng một cú nhấp chuột."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 9: SHIPPER NỘP TIỀN CA TRỰC (MOBILE & WEB)
    # -------------------------------------------------------------
    p_sc9 = doc.add_paragraph()
    p_sc9.paragraph_format.space_before = Pt(12)
    r = p_sc9.add_run("KỊCH BẢN 9: SHIPPER NỘP TIỀN CA TRỰC & ĐỐI SOÁT TÀI CHÍNH")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="9.1",
        title="Shipper xem tổng kết doanh thu ca trực & Tạo phiếu nộp tiền",
        actor="Nhân viên Giao nhận (Shipper)",
        screen="Mobile App (shipper_screen.dart - Tab 'Đã hoàn tất')",
        action="1. Cuối ca làm việc, Shipper vào tab 'Đã hoàn tất'.\n"
               "2. Xem các chỉ số tài chính ca trực hiển thị trên đầu màn hình:\n"
               "   - Tiền mặt COD cần nộp lại: 190.000đ\n"
               "   - Tiền khách chuyển khoản: 110.000đ\n"
               "   - Số đơn hoàn thành: 3 đơn\n"
               "3. Bấm nút 'Nộp tiền ca trực' màu đỏ ở góc trên bên phải.",
        expected="Màn hình xác nhận nộp tiền ca trực mở ra với mã phiên bàn giao ShiftHandover, kê khai chi tiết số tiền mặt shipper đang giữ và danh sách các đơn COD tương ứng.",
        speech="Vào cuối ngày, Shipper không thể tự ý rời ca nếu chưa đối soát tài chính. Shipper mở tab Đã hoàn tất, kiểm tra số tiền mặt COD thực thu và bấm nút Nộp tiền ca trực."
    )
    
    add_step_card(
        doc,
        step_num="9.2",
        title="Thủ quỹ xưởng giặt kiểm đếm & Chốt sổ bàn giao ca trực",
        actor="Thủ quỹ / Quản lý (Staff / Cashier)",
        screen="Web Admin (dispatch.html - Tab 'Nộp tiền ca' hoặc orders.html)",
        action="1. Shipper nộp 190.000đ tiền mặt tại quầy thu ngân của xưởng 3T.\n"
               "2. Nhân viên thu ngân mở tab 'Giám sát tài chính shipper'.\n"
               "3. Kiểm tra số tiền shipper nộp trùng khớp 100% với số liệu phần mềm tính toán.\n"
               "4. Bấm nút xanh 'Xác nhận Đã Thu Đủ Tiền Ca Trực'.",
        expected="Phiếu nộp tiền chuyển trạng thái 'Confirmed'. Tiền mặt được cộng vào Quỹ tiền mặt của xưởng giặt. Số dư COD cần nộp của Shipper trở về 0đ. Shipper chính thức hoàn thành ca làm việc an toàn.",
        speech="Thủ quỹ xưởng giặt kiểm tiền và bấm xác nhận. Dòng tiền được đối soát khép kín giữa tiền mặt COD và tiền chuyển khoản VietQR, loại bỏ 100% rủi ro thất thoát doanh thu."
    )
    
    # -------------------------------------------------------------
    # KỊCH BẢN 10: BÁO CÁO THỐNG KÊ, KHO VẬT TƯ & KHÁCH HÀNG
    # -------------------------------------------------------------
    p_sc10 = doc.add_paragraph()
    p_sc10.paragraph_format.space_before = Pt(12)
    r = p_sc10.add_run("KỊCH BẢN 10: QUẢN LÝ KHO VẬT TƯ, CRM KHÁCH HÀNG & BÁO CÁO DOANH THU")
    r.font.name = "Calibri"
    r.font.size = Pt(12.5)
    r.bold = True
    r.font.color.rgb = RGBColor(30, 58, 138)
    
    add_step_card(
        doc,
        step_num="10.1",
        title="Xem biểu đồ báo cáo doanh thu & Phân tích cơ cấu dịch vụ",
        actor="Chủ xưởng / Quản lý cấp cao (Admin / Manager)",
        screen="Web Admin (http://localhost:5500/reports.html)",
        action="1. Bấm menu 'Báo cáo & Thống kê' (reports.html).\n"
               "2. Xem biểu đồ cột Doanh thu theo ngày/tháng.\n"
               "3. Xem biểu đồ tròn cơ cấu dịch vụ: Giặt sấy theo kg (45%), Giặt hấp comple (35%), Giặt giày (20%).\n"
               "4. Bấm nút 'Xuất báo cáo Excel / PDF'.",
        expected="Các biểu đồ Chart.js trực quan phản ánh tình hình kinh doanh, tỷ lệ tăng trưởng và hiệu suất giao nhận của đội ngũ Shipper.",
        speech="Phân hệ Báo cáo giúp chủ xưởng nắm bắt doanh thu theo thời gian thực, biết được dịch vụ nào mang lại tỷ suất lợi nhuận cao nhất để tối ưu chiến lược kinh doanh."
    )
    
    add_step_card(
        doc,
        step_num="10.2",
        title="Quản lý tồn kho vật tư hóa chất & Cảnh báo an toàn kho",
        actor="Quản lý kho (Staff)",
        screen="Web Admin (http://localhost:5500/inventory.html)",
        action="1. Bấm menu 'Kho vật tư' (inventory.html).\n"
               "2. Kiểm tra danh mục nguyên phụ liệu: Nước giặt OMO Matic công nghiệp (còn 45 lít), Nước xả Comfort Ban Mai (còn 20 lít), Dây seal niêm phong (còn 350 chiếc).\n"
               "3. Nhập số lượng nhập kho mới: Nhập thêm 50 lít nước giặt và bấm 'Lưu phiếu nhập kho'.",
        expected="Số lượng tồn kho được tự động cập nhật. Khi mức tồn dưới ngưỡng định mức an toàn, thẻ vật tư sẽ đổi sang màu đỏ cảnh báo cần mua bổ sung.",
        speech="Phần mềm quản lý tự động trừ kho nguyên liệu theo từng kg quần áo giặt xong và cảnh báo khi sắp hết hóa chất hoặc tem seal niêm phong."
    )
    
    doc.add_page_break()
    
    # -------------------------------------------------------------
    # PHẦN 4: BỘ CÂU HỎI PHẢN BIỆN & LỜI THOẠI TRƯỚC HỘI ĐỒNG
    # -------------------------------------------------------------
    p_h1 = doc.add_paragraph()
    r = p_h1.add_run("PHẦN 4: KỊCH BẢN THUYẾT TRÌNH & CÂU HỎI PHẢN BIỆN HỘI ĐỒNG")
    r.font.name = "Calibri"
    r.font.size = Pt(14)
    r.bold = True
    r.font.color.rgb = RGBColor(138, 21, 56)
    
    p = doc.add_paragraph()
    p.add_run(
        "Dưới đây là kịch bản phân bổ thời gian khi trình bày trước Hội đồng và 8 câu hỏi phản biện "
        "thường gặp nhất của các thầy cô chấm thi cùng câu trả lời chuẩn xác nhất:"
    )
    
    # Timeline trình bày
    time_headers = ["Thời lượng", "Nội dung trình bày trọng tâm", "Phân hệ tương ứng"]
    time_data = [
        ["Phút 00 - 02", "Giới thiệu đề tài, tính cấp thiết, lý do chọn đề tài và kiến trúc tổng quan", "Slide báo cáo"],
        ["Phút 02 - 05", "Demo Khách hàng đặt đơn, chọn dịch vụ cao cấp, áp mã voucher và gửi đơn", "Mobile Flutter Web (5000)"],
        ["Phút 05 - 08", "Demo Web Admin duyệt đơn, điều phối Bản đồ số OSRM và phân công Shipper", "Web Admin (5500)"],
        ["Phút 08 - 11", "Demo Shipper nhận việc, mở Google Maps, quét Seal niêm phong và chụp ảnh giao", "Mobile Shipper (5000)"],
        ["Phút 11 - 13", "Demo Hóa đơn điện tử E-Invoice, Bảo hiểm 3T Care khiếu nại tải ảnh thật 60 phút", "Mobile & Web Admin"],
        ["Phút 13 - 15", "Demo Nộp tiền ca trực COD, Báo cáo thống kê, kết luận và trả lời câu hỏi phản biện", "Web Admin & Tổng kết"]
    ]
    add_custom_table(doc, time_headers, time_data, [1.4, 3.6, 1.5])
    
    # Top câu hỏi phản biện
    qa_list = [
        (
            "Câu hỏi 1: Tại sao hệ thống lại yêu cầu quy trình Niêm phong Seal và Chụp ảnh giao hàng?",
            "Trả lời: Trong ngành giặt ủi truyền thống, rủi ro lớn nhất là tranh chấp khách hàng khi quần áo bị thất lạc, nhầm lẫn hoặc rách hỏng không rõ nguyên nhân. Mã Seal niêm phong WS-SEAL tạo rào cản vật lý và minh bạch: shipper và khách cùng bấm seal, shipper chụp ảnh tải lên máy chủ. Khi giao đồ sạch, shipper chụp ảnh thực tế tận tay. Hai bức ảnh này đóng vai trò bằng chứng số (Digital Evidence) giúp loại bỏ 100% gian lận và bảo vệ cả khách hàng lẫn xưởng giặt."
        ),
        (
            "Câu hỏi 2: Tại sao tính năng Khiếu nại bảo hiểm 3T Care lại bị giới hạn trong 60 phút sau khi giao?",
            "Trả lời: Quy định 60 phút là chuẩn mực dịch vụ để đảm bảo tính xác thực của sự cố. Khách hàng khi nhận đồ sạch có đủ thời gian kiểm tra ngay trước khi cất vào tủ. Nếu để qua ngày hôm sau, quần áo có thể bị vấy bẩn hoặc tác động từ môi trường bên ngoài của khách nhưng lại quy trách nhiệm cho xưởng giặt. Quy định 60 phút vừa đảm bảo quyền lợi khách hàng, vừa bảo vệ xưởng giặt một cách công bằng."
        ),
        (
            "Câu hỏi 3: Bản đồ số điều phối của nhóm sử dụng công nghệ gì và giải quyết bài toán gì?",
            "Trả lời: Chúng em tích hợp Leaflet Map kết hợp máy chủ định tuyến mã nguồn mở OSRM (Open Source Routing Machine). Bản đồ giải quyết 3 bài toán thực tế: (1) Trực quan hóa tọa độ các đơn hàng cần lấy và cần giao trên nền bản đồ TP.HCM; (2) Chỉ hiển thị các Shipper đang trực tuyến (Online) và xuất phát từ cửa hàng 140 Lê Trọng Tấn; (3) Tự động vẽ lộ trình đường bộ ngắn nhất và cung cấp liên kết mở trực tiếp trên Google Maps cho Shipper lái xe."
        ),
        (
            "Câu hỏi 4: Cơ chế bảo mật và phân quyền giữa các vai trò trong hệ thống được hiện thực như thế nào?",
            "Trả lời: Hệ thống sử dụng cơ chế xác thực JWT (JSON Web Token) kết hợp mã hóa mật khẩu một chiều BCrypt. Các API trên Backend .NET 8 được bảo vệ bằng thuộc tính [Authorize(Roles = '...')] nghiêm ngặt. Khách hàng chỉ xem được đơn của mình, Shipper chỉ xem được đơn được phân công, và chỉ Admin/Staff mới có quyền duyệt đơn, chỉnh sửa danh mục dịch vụ và xem báo cáo tài chính."
        ),
        (
            "Câu hỏi 5: Khi mất kết nối mạng hoặc lỗi HTTP 401 thì ứng dụng xử lý thế nào?",
            "Trả lời: Khi token JWT hết hạn (HTTP 401), ứng dụng tự động hiển thị hộp thoại thông báo phiên đăng nhập hết hạn và điều hướng người dùng đăng nhập lại nhanh chóng. Với bản đồ OSRM, nếu mạng gặp sự cố, hệ thống có cơ chế Fallback tính toán cự ly chim bay theo công thức Haversine để không bao giờ bị gián đoạn thao tác điều phối."
        )
    ]
    
    for q, a in qa_list:
        add_callout(doc, f"{a}", title=f"HỎI ĐÁP PHẢN BIỆN: {q}", alert_type="note")
        
    # Lời kết
    p_end = doc.add_paragraph()
    p_end.paragraph_format.space_before = Pt(16)
    p_end.paragraph_format.line_spacing = 1.2
    r_end = p_end.add_run(
        "TÀI LIỆU NÀY LÀ TỔNG HỢP TOÀN BỘ TÂM HUYẾT VÀ KẾT QUẢ NGHIÊN CỨU THỰC NGHIỆM CỦA ĐỀ TÀI. "
        "CHÚC BUỔI BẢO VỆ ĐỒ ÁN TỐT NGHIỆP CỦA SINH VIÊN DIỄN RA THÀNH CÔNG RỰC RỠ VÀ ĐẠT KẾT QUẢ CAO NHẤT!"
    )
    r_end.bold = True
    r_end.font.color.rgb = RGBColor(138, 21, 56)
    
    # Save document
    output_path = os.path.abspath("WashSmart3T_TaiLieu_HuongDan_KichBan_Demo.docx")
    doc.save(output_path)
    print(f"Document successfully created at: {output_path}")

if __name__ == "__main__":
    build_document()
