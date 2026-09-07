# Tài Liệu Đặc Tả Kỹ Thuật Ingestion API (MISA AMIS CRM)

## 1. Tổng quan & Phạm vi
Tài liệu này đặc tả giao tiếp chuẩn để các công cụ thu thập dữ liệu (điển hình là Chrome Extension nhúng trên Zalo Web) gửi lịch sử hội thoại trao đổi giữa Nhân viên Kinh doanh (NVKD) và Khách hàng về kho dữ liệu trung tâm của MISA AMIS CRM (`https://misajsc.amis.vn/crm`).

Dữ liệu này sau đó là đầu vào trực tiếp cho **Hệ Thống Trí Tuệ Nhân Tạo (AI Customer Discovery Engine)** tự động nhận diện thông tin doanh nghiệp (MST, CCCD) và tóm tắt 7 mục chân dung khách hàng vào hồ sơ CRM.

---

## 2. Thông tin Kết nối Chung
- **Môi trường chính thức (Production)**: `https://misajsc.amis.vn/crm/api/v1`
- **Phương thức bảo mật & Xác thực**: **BẮT BUỘC** truyền Token qua HTTP Header theo định dạng `Bearer Token`.
  - Header name: `Authorization`
  - Header value: `Bearer <MISA_AMIS_API_KEY>`
  - *Lưu ý*: Hệ thống từ chối mọi yêu cầu truyền token qua Request Body hoặc Query Parameter để đảm bảo an toàn bảo mật.

---

## 3. Chi tiết API Endpoint

### `POST /zalo/sync`
Nhận danh sách tin nhắn hội thoại Zalo theo mảng JSON để đẩy vào luồng đệm Message Queue (Kafka/RabbitMQ) xử lý bất đồng bộ.

#### 3.1. Header Quy Định
| Tên Header | Bắt buộc | Kiểu dữ liệu | Ví dụ / Ghi chú |
| :--- | :---: | :--- | :--- |
| `Content-Type` | **Có** | `string` | `application/json` |
| `Authorization` | **Có** | `string` | `Bearer eyJhbGciOi...` (Token cấp từ MISA AMIS CRM) |

#### 3.2. Cấu trúc Payload Request (JSON Array)
Payload gửi lên là một danh sách các tin nhắn (`Array of ChatMessage`). Mỗi phần tử gồm các trường sau:

| Tên trường | Kiểu dữ liệu | Bắt buộc | Mô tả nghiệp vụ |
| :--- | :--- | :---: | :--- |
| `Sender` | `string` | **Có** | Tên người gửi tin nhắn (Tên NVKD hoặc Tên Khách hàng). |
| `ContactName` | `string` | **Có** | Tên người/nhóm hội thoại hiển thị tại khung chat Zalo. Có thể đính kèm MST (10/13 số) hoặc CCCD (12 số). |
| `IP` | `string` | Không | Địa chỉ IP máy trạm gửi tin nhắn để phục vụ kiểm toán bảo mật. |
| `Time` | `string` | **Có** | Thời gian gửi tin nhắn hiển thị trên giao diện Zalo (Ví dụ: `14:32:00 07/09/2026`). |
| `Content` | `string` | **Có** | Nội dung tin nhắn trao đổi thực tế. |

#### 3.3. Ví dụ Payload Request (Gửi từ Extension / Client)
```json
[
  {
    "Sender": "Nguyễn Văn Kinh Doanh",
    "ContactName": "Công ty CP Sản Xuất ABC (MST: 0101234567)",
    "IP": "118.70.12.34",
    "Time": "14:32:00 07/09/2026",
    "Content": "Dạ em chào anh Nam, hiện tại đơn vị mình đang có bao nhiêu nhân sự vận hành hệ thống CRM ạ?"
  },
  {
    "Sender": "Công ty CP Sản Xuất ABC (MST: 0101234567)",
    "ContactName": "Công ty CP Sản Xuất ABC (MST: 0101234567)",
    "IP": "118.70.12.34",
    "Time": "14:33:15 07/09/2026",
    "Content": "Chào em, bên anh có 120 nhân sự, gồm 3 chi nhánh Hà Nội, Đà Nẵng, HCM. Hiện đang quản lý bằng Excel nên rất rối."
  }
]
```

---

## 4. Phản Hồi Từ Máy Chủ (Server Responses)

### 4.1. Thành công: `200 OK`
Khi dữ liệu hợp lệ và đã được ghi nhận thành công vào luồng đệm Message Queue:
```json
{
  "success": true,
  "code": 200,
  "message": "Đã tiếp nhận 2 tin nhắn vào hàng đợi AI Discovery Engine.",
  "data": {
    "batchId": "batch-20260907-8912",
    "processedCount": 2,
    "receivedAt": "2026-09-07T15:30:00+07:00"
  }
}
```

### 4.2. Lỗi dữ liệu: `400 Bad Request`
Dữ liệu gửi lên không phải mảng, thiếu trường bắt buộc hoặc mảng rỗng:
```json
{
  "success": false,
  "code": 400,
  "error": "BAD_REQUEST",
  "message": "Payload không hợp lệ: Yêu cầu mảng chứa ít nhất một tin nhắn có đủ Sender, ContactName, Time, Content."
}
```

### 4.3. Lỗi xác thực: `401 Unauthorized`
Thiếu header `Authorization` hoặc token sai/hết hạn:
```json
{
  "success": false,
  "code": 401,
  "error": "UNAUTHORIZED",
  "message": "Header 'Authorization: Bearer <token>' không hợp lệ hoặc tài khoản không có quyền đồng bộ dữ liệu."
}
```

### 4.4. Lỗi hệ thống: `500 Internal Server Error`
Máy chủ gặp sự cố hoặc cụm Kafka/Database không phản hồi:
```json
{
  "success": false,
  "code": 500,
  "error": "INTERNAL_SERVER_ERROR",
  "message": "Không thể đẩy dữ liệu vào hàng đợi. Đội ngũ kỹ thuật đã được thông báo."
}
```

---

## 5. Mẫu Mã Lệnh Kiểm Thử (cURL)

```bash
curl -X POST "https://misajsc.amis.vn/crm/api/v1/zalo/sync" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer s3cr3t_jwt_t0k3n_fr0m_amis_crm" \
  -d '[
    {
      "Sender": "Nguyễn Văn Kinh Doanh",
      "ContactName": "Chị Mai - CFO (0301987654)",
      "IP": "14.248.82.10",
      "Time": "09:15:00 07/09/2026",
      "Content": "Dự kiến quý 4 bên chị có ngân sách khoảng 150 triệu cho phần mềm quản lý không ạ?"
    }
  ]'
```

---

## 6. Luồng Xử Lý Kế Tiếp Sau Khi Nhận Dữ Liệu
1. **Ghi đệm Message Queue**: Ingestion API xác thực Token, chuyển payload vào Kafka Topic `zalo.messages.raw`.
2. **Lưu trữ Lịch Sử (Chat Lake)**: Kafka Consumer đẩy tin nhắn vào cơ sở dữ liệu PostgreSQL/MongoDB theo cặp `(Sender, ContactName)`.
3. **AI Discovery Worker**:
   - Tách MST (10 hoặc 13 số) / CCCD (12 số) từ `ContactName` hoặc `Content`.
   - Gom toàn bộ hội thoại và đưa vào Local LLM chạy Prompt 7 mục khám phá khách hàng.
   - Ghi kết quả tóm tắt trực tiếp vào **Thẻ Khách hàng 360** trên MISA AMIS CRM (`https://misajsc.amis.vn/crm`).
