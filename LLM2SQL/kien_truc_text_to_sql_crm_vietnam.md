# TÀI LIỆU THIẾT KẾ KIẾN TRÚC & HƯỚNG DẪN TRIỂN KHAI TEXT-TO-SQL CHO HỆ THỐNG CRM
## Ứng dụng các mẫu hình từ Arun Shankar (LLM-Text-to-SQL-Architectures) & Awesome-Text2SQL
### (Tối ưu hóa cho hạ tầng thuần CPU, Black-Box LLM nội bộ & Nghiệp vụ CRM Việt Nam)

---

## 1. PHÂN TÍCH 5 MẪU KIẾN TRÚC TỪ ARUN SHANKAR & TÍNH KHẢ THI TRÊN CPU

Nghiên cứu từ kho lưu trữ `arunpshankar/LLM-Text-to-SQL-Architectures` đề xuất 5 mô hình kiến trúc chuẩn để chuyển đổi ngôn ngữ tự nhiên thành truy vấn cơ sở dữ liệu:

| Pattern (Mẫu kiến trúc) | Bản chất vận hành | Ưu điểm | Hạn chế với bài toán CRM | Mức độ áp dụng |
| :--- | :--- | :--- | :--- | :--- |
| **Pattern I: Intent & Entity Recognition** | Bóc tách ý định (Intent) và thực thể (Entity) bằng LLM/Logic trước khi sinh SQL. | Giúp hiểu sâu câu hỏi, không nhầm lẫn điều kiện lọc thời gian, địa danh, loại hình B2B/B2C. | Nếu gọi LLM thêm một lượt sẽ tăng độ trễ (latency). | **Cốt lõi**: Chuyển công đoạn này sang **CPU rule-based** (dưới $5\text{ms}$). |
| **Pattern II: Schema RAG** | Dùng RAG để tìm bảng và cột liên quan từ siêu dữ liệu (Metadata) thay vì nhét cả database. | Giảm tải ngữ cảnh, tránh làm tràn bộ nhớ Prompt của Black-Box LLM. | Thường cần Vector DB nặng nếu dùng Deep Learning. | **Cốt lõi**: Thay thế Vector DB bằng **Bảng tra cứu Metadata + Graph Khóa ngoại** trên CPU. |
| **Pattern III: Autonomous SQL Agent (ReAct)** | AI Agent tự do thử - sai, gọi tool kiểm tra bảng, chạy thử query liên tục qua ODBC. | Linh hoạt, tự thích nghi với schema phức tạp. | Rất chậm, dễ rơi vào vòng lặp vô tận, rủi ro bảo mật cao, tốn token nội bộ. | **Không dùng nguyên bản**: Thay bằng quy trình hữu hạn có kiểm soát. |
| **Pattern IV: Direct Schema Inference & Self-Correction** | Đưa schema chọn lọc vào LLM, thực thi thử trên DB; nếu lỗi thì gửi lỗi ngược lại để LLM tự sửa. | Tăng độ chính xác lên trên 85%, giải quyết triệt để lỗi gõ sai tên cột, sai hàm ngày tháng. | Cần cơ chế giới hạn số lần thử lại (tối đa 2 - 3 lần). | **Cốt lõi**: Bắt buộc triển khai kết hợp với lệnh `EXPLAIN` trên DB Read-Only. |
| **Pattern V: Stochastic Optimization & Best Candidate** | Sinh nhiều truy vấn cùng lúc (nhiệt độ ngẫu nhiên), chạy đo thời gian và chọn câu tối ưu nhất. | Đảm bảo truy vấn không làm nghẽn Database CRM. | Tốn tài nguyên tính toán nếu chạy 5 - 10 câu lệnh cùng lúc trên DB thật. | **Áp dụng tinh gọn**: Dùng bộ phân tích chi phí `EXPLAIN (COST)` để chọn câu lệnh nhẹ nhất. |

---

## 2. KIẾN TRÚC TỔNG HỢP: HYBRID PIPELINE (KẾT HỢP PATTERN I, II, IV & V)

Để thỏa mãn triệt để các ràng buộc **100% CPU, Black-Box LLM, không can thiệp weights, database CRM nhiều bảng phức tạp**, hệ thống triển khai theo mô hình kiến trúc lai:

```
flowchart TB
    User([Nhân viên Sales / CSKH]) -->|Nhập câu hỏi tiếng Việt| Gateway[Cổng CRM / Webhook API]

    subgraph CPU_Orchestrator [Bộ Điều Phối Trung Tâm - Xử Lý Thuần CPU]
        direction TB
        
        %% Pattern I
        subgraph Stage1 [Giai Đoạn 1: Phân Tích Ý Định & Thực Thể - Pattern I]
            IntentParser[Bộ phân loại ý định: Báo cáo / Xếp hạng / Tra cứu]
            EntityExtractor[Trích xuất thực thể: Doanh thu, Q3/2026, Hà Nội, B2B]
        end

        %% Pattern II
        subgraph Stage2 [Giai Đoạn 2: Định Vị Lược Đồ Thuần CPU - Pattern II]
            SchemaMatcher[Lọc bảng & cột liên quan bằng từ khóa nghiệp vụ]
            GraphConnector[Thuật toán cầu nối: Bổ sung bảng trung gian qua Khóa Ngoại]
        end

        %% DAIL-SQL Few-Shot Selection
        subgraph Stage3 [Giai Đoạn 3: Tuyển Chọn Mẫu Few-Shot Chuẩn Khung Xương]
            SkeletonMatcher[Khớp khung xương cú pháp SQL tương ứng]
        end

        %% Prompt Assembly
        PromptBuilder[Giai Đoạn 4: Lắp ráp Prompt chuẩn hóa]

        %% Pattern IV & V
        subgraph Stage4 [Giai Đoạn 5: Động Cơ Tự Sửa Lỗi & Tối Ưu Hóa - Pattern IV & V]
            ASTSecurity[Lớp 1: Kiểm tra an toàn tĩnh AST - Chỉ cho SELECT]
            ExplainValidator[Lớp 2: Kiểm tra ngữ nghĩa ảo bằng EXPLAIN trên DB]
            CostSelector[Lớp 3: Đánh giá chi phí tài nguyên & Giới hạn Timeout]
        end
    end

    subgraph LLM_Cloud [Mô Hình Ngôn Ngữ Nội Bộ]
        BlackBoxLLM[Black-Box LLM API\n(Không weights, chỉ nhận Prompt)]
    end

    subgraph CRM_Storage [Cơ Sở Dữ Liệu CRM]
        BusinessOntology[(Từ Điển Khái Niệm CRM)]
        GoldenStore[(Kho Cặp Mẫu SQL Chuẩn)]
        ReadReplica[(CRM Read-Replica DB\nMySQL / PostgreSQL)]
    end

    Gateway --> Stage1
    Stage1 --> Stage2
    BusinessOntology -.-> Stage1
    BusinessOntology -.-> Stage2

    Stage2 --> Stage3
    GoldenStore -.-> Stage3

    Stage3 --> PromptBuilder
    PromptBuilder -->|Gửi Prompt rút gọn| BlackBoxLLM

    BlackBoxLLM -->|Trả về Raw SQL| ASTSecurity
    ASTSecurity -->|Hợp lệ| ExplainValidator

    ExplainValidator <-->|Chạy thử nghiệm EXPLAIN| ReadReplica
    ExplainValidator -->|Nếu DB báo lỗi cột/bảng| BlackBoxLLM

    ExplainValidator -->|SQL chạy thành công| CostSelector
    CostSelector -->|Thực thi chính thức với LIMIT| ReadReplica
    ReadReplica -->|Dữ liệu bảng kết quả| Gateway
```

---

## 3. ĐẶC TẢ CHI TIẾT CÁC KHỐI CHỨC NĂNG & GIẢI THUẬT DỄ HIỂU

### 3.1. Khối 1: Phân tích Ý định & Thực thể CRM (Ứng dụng Pattern I)

#### Mục tiêu:
Hiểu rõ người dùng muốn gì trước khi chạm vào cơ sở dữ liệu. Bóc tách câu hỏi thành các "mảnh ghép thông tin" chuẩn hóa.

#### Cách giải quyết không dùng AI nặng (CPU Rule-Based):
1. **Nhận diện Ý định (Intent)**:
   * **Ý định xếp hạng (Top-N/Ranking)**: Phát hiện các từ như *"top", "nhất", "cao nhất", "ít nhất"*. $\to$ Cần sinh mệnh đề `ORDER BY ... LIMIT N`.
   * **Ý định thống kê (Aggregation)**: Phát hiện các từ như *"tổng", "doanh số", "trung bình", "bao nhiêu"*. $\to$ Cần dùng các hàm `SUM`, `COUNT`, `AVG` và mệnh đề `GROUP BY`.
   * **Ý định tìm kiếm chi tiết (Lookup)**: Phát hiện từ *"danh sách", "thông tin chi tiết", "số điện thoại"*. $\to$ Lấy trực tiếp danh sách cột thông tin.
2. **Nhận diện Thực thể (Entity Extraction)**:
   * **Thực thể thời gian**: Ánh xạ *"tháng này"*, *"quý này"*, *"năm ngoái"* sang mốc ngày cụ thể dựa vào đồng hồ hệ thống.
   * **Thực thể phân loại khách hàng**: Ánh xạ *"doanh nghiệp", "công ty"* thành `customer_type = 'B2B'`; *"cá nhân", "khách lẻ"* thành `customer_type = 'B2C'`.
   * **Thực thể địa lý**: Ánh xạ từ viết tắt (*"HN", "Sài Gòn", "ĐN"*) về tên chuẩn trong cơ sở dữ liệu (*"Hà Nội", "Hồ Chí Minh", "Đà Nẵng"*).

---

### 3.2. Khối 2: Định vị Lược đồ & Tìm Cầu Nối (Ứng dụng Pattern II)

#### Mục tiêu:
Cắt tỉa 90% số bảng dư thừa trong CRM, chỉ giữ lại đúng các bảng và cột cần dùng, đồng thời tự động bổ sung bảng trung gian để câu lệnh `JOIN` không bị đứt đoạn.

#### Thuật toán trực quan (Không công thức):
1. **Lọc bảng theo điểm quan tâm (Keyword Relevance)**:
   * Từng bảng trong CRM được chấm điểm: Nếu câu hỏi nhắc đến chữ "đơn hàng", bảng `orders` nhận điểm cao. Nếu nhắc đến "sản phẩm", bảng `products` nhận điểm cao.
   * Lấy ra 2 đến 3 bảng hạt nhân có điểm cao nhất.
2. **Thuật toán "Bản đồ nối cầu" (Foreign Key Connector)**:
   * *Tình huống*: Người dùng hỏi về "Khách hàng" và "Sản phẩm". Hai bảng này nằm tách biệt, không nối trực tiếp.
   * *Giải pháp*: Coi mỗi bảng là một điểm dừng chân. Thuật toán kiểm tra các khóa ngoại (Foreign Key) để tìm lộ trình ngắn nhất kết nối hai điểm này:
     $$\text{customers} \longrightarrow \text{orders} \longrightarrow \text{order_items} \longrightarrow \text{products}$$
   * Hệ thống tự động thêm `orders` và `order_items` vào danh sách gửi cho AI, giúp AI biết chính xác cách viết lệnh `JOIN` mà không tự bịa bảng.

---

### 3.3. Khối 3: Tuyển chọn Ví dụ Mẫu Chuẩn Khung Xương (Theo DAIL-SQL)

#### Mục tiêu:
Black-Box LLM học rất nhanh qua ví dụ (In-Context Learning). Thay vì chọn ngẫu nhiên, ta chọn ví dụ có **cấu trúc logic giống nhất** với câu hỏi hiện tại.

#### Cơ chế khớp khung sườn (Skeleton Matching):
1. Mỗi câu SQL trong kho mẫu được rút gọn thành "khung xương":
   * Câu hỏi: *"Top 5 khách hàng chi tiêu nhiều nhất"* $\to$ Khung xương: `SELECT [cột] FROM [bảng] JOIN [bảng] WHERE [điều kiện] GROUP BY [cột] ORDER BY [hàm] DESC LIMIT N`.
   * Câu hỏi: *"Đếm số cơ hội mới trong tuần"* $\to$ Khung xương: `SELECT COUNT([cột]) FROM [bảng] WHERE [ngày] >= [mốc]`.
2. Dựa vào Ý định (Intent) đã phân tích ở Khối 1, hệ thống chỉ lấy **1 đến 2 ví dụ có khung xương khớp nhất** để đưa vào Prompt, giúp AI sao chép đúng phong cách lập luận.

---

### 3.4. Khối 4: Tự Sửa Lỗi Hướng Thực Thi (Ứng dụng Pattern IV)

#### Mục tiêu:
Loại bỏ hoàn toàn tình trạng AI sinh câu lệnh SQL chứa cột không tồn tại, sai kiểu dữ liệu hoặc sai cú pháp cơ bản.

```
       ┌────────────────────────────────────────────────────────┐
       │             LLM sinh câu lệnh SQL thô                  │
       └───────────────────────────┬────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │   Bước 1: Kiểm tra cú pháp tĩnh AST                    │
       │   - Bắt buộc là câu lệnh SELECT duy nhất               │
       │   - Cấm hoàn toàn: INSERT, UPDATE, DELETE, DROP...     │
       └───────────────────────────┬────────────────────────────┘
                                   │ Hợp lệ cú pháp
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │   Bước 2: Thẩm định ảo trên Read-Replica DB             │
       │   Chạy lệnh: EXPLAIN (FORMAT JSON) <câu_lệnh_SQL>      │
       └───────────────────────────┬────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
              Có thông báo lỗi              Không có lỗi (Thành công)
                    │                             │
                    ▼                             ▼
┌───────────────────────────────────────┐ ┌─────────────────────────────┐
│ Bước 3: Đóng gói phản hồi lỗi (Feedback)│ │ Bước 4: Chuyển sang kiểm tra│
│ - Tên lỗi cụ thể từ DB                │ │ chi phí & thực thi an toàn  │
│ - Chỉ dẫn cột/bảng thay thế           │ └─────────────────────────────┘
└───────────────────┬───────────────────┘
                    │
                    ▼
┌───────────────────────────────────────┐
│ Gửi lại cho LLM (Tối đa 2 lần thử):   │
│ "Câu lệnh bị lỗi: [thông báo].        │
│ Bảng X chỉ có cột Y, không có cột Z.  │
│ Hãy sửa lại câu SQL trên."            │
└───────────────────────────────────────┘
```

#### Bảng quy đổi thông điệp sửa lỗi thông minh:

| Lỗi DB nhận diện qua EXPLAIN | Bản chất lỗi | Thông điệp phản hồi gửi lại LLM |
| :--- | :--- | :--- |
| **Unknown column / Column does not exist** | LLM tự bịa tên cột hoặc dùng sai bảng | *"Cột bạn vừa dùng không tồn tại. Xem lại danh sách cột hợp lệ của bảng này và chỉ được chọn trong danh sách đó."* |
| **Table does not exist** | LLM gõ sai tên bảng hoặc thiếu tiền tố | *"Bảng bạn truy vấn không có thực trong schema. Hãy chỉ dùng các bảng được cấp trong prompt."* |
| **Not in GROUP BY clause** | Thiếu cột không tổng hợp trong `GROUP BY` | *"Cột bạn SELECT chưa được tổng hợp (bằng SUM/AVG/COUNT) và chưa có trong GROUP BY. Hãy thêm cột này vào GROUP BY."* |
| **Type mismatch / Operator does not exist** | Đem so sánh chuỗi với ngày tháng hoặc số | *"Sai kiểu dữ liệu khi so sánh. Hãy dùng định dạng chuẩn ISO (YYYY-MM-DD) hoặc ép kiểu phù hợp."* |

---

### 3.5. Khối 5: Tối Ưu Hóa & Lựa Chọn Ứng Viên (Ứng dụng Pattern V)

#### Mục tiêu:
Đảm bảo câu lệnh SQL do AI viết ra không chỉ đúng ngữ pháp mà còn phải **chạy nhanh**, không làm nghẽn hoặc sập cơ sở dữ liệu CRM.

#### Nguyên lý vận hành tinh gọn:
1. **Kiểm tra chi phí dự phóng (Execution Cost Check)**:
   * Khi chạy lệnh `EXPLAIN`, cơ sở dữ liệu trả về chỉ số chi phí ước lượng (`Total Cost`) và số dòng cần quét (`Rows Scanned`).
   * Nếu phát hiện câu lệnh quét toàn bộ bảng (Full Table Scan) trên bảng có hàng triệu bản ghi mà thiếu điều kiện thời gian hoặc thiếu chỉ mục (Index), hệ thống can thiệp:
     * Tự động thêm điều kiện chặn thời gian mặc định (ví dụ: chỉ quét trong 12 tháng gần nhất).
     * Bắt buộc có mệnh đề `LIMIT 100`.
2. **Kiểm soát thời gian phản hồi (Hard Timeout)**:
   * Thiết lập ngắt cứng kết nối ở mức 3 giây (`statement_timeout = 3000`). Nếu câu lệnh chạy quá thời gian này, hệ thống hủy truy vấn ngay lập tức và thông báo người dùng thu hẹp khoảng thời gian tìm kiếm.

---

## 4. BẢN ĐỊA HÓA NGHIỆP VỤ (ONTOLOGY) CHO SALES & SUPPORT VIỆT NAM

Tầng tiền xử lý trên CPU được trang bị một bảng đối chiếu từ vựng thực tế của các doanh nghiệp tại Việt Nam:

| Ngôn ngữ nói thường dùng | Bản chất nghiệp vụ CRM | Điều kiện chuẩn hóa bắt buộc trong SQL |
| :--- | :--- | :--- |
| **"Khách B2B", "Khách công ty", "Doanh nghiệp"** | Khách hàng là tổ chức | `customers.customer_type = 'B2B'` |
| **"Khách B2C", "Khách lẻ", "Cá nhân"** | Khách hàng là người tiêu dùng | `customers.customer_type = 'B2C'` |
| **"Doanh số", "Doanh thu", "Tiền về"** | Tổng giá trị các đơn thành công | `SUM(orders.total_amount)` kèm điều kiện `orders.status = 'COMPLETED'` |
| **"Đơn treo", "Chưa trả tiền", "Đang ship"** | Đơn hàng trong tiến trình xử lý | `orders.status IN ('PENDING', 'PROCESSING', 'SHIPPING')` |
| **"Hôm nay", "Trong ngày"** | Ngày hiện tại | `orders.created_at >= CURRENT_DATE` |
| **"Tháng này"** | Từ đầu tháng hiện tại tới nay | `orders.created_at >= DATE_TRUNC('month', CURRENT_DATE)` |
| **"Quý này"** | Từ ngày đầu tiên của quý hiện tại | `orders.created_at >= DATE_TRUNC('quarter', CURRENT_DATE)` |
| **"Hà Nội", "HN", "Sài Gòn", "HCM", "ĐN"** | Tên thành phố | Chuẩn hóa sang tên chính thức: `'Hà Nội'`, `'Hồ Chí Minh'`, `'Đà Nẵng'` |

---

## 5. MẪU KHUNG PROMPT CHUẨN ĐỂ GỬI TỚI BLACK-BOX LLM

Khung prompt dưới đây được tinh giản tối đa, chứa đủ 4 thành phần thiết yếu (Thời gian thực, Lược đồ tối giản, Quy tắc nghiệp vụ cứng, Ví dụ mẫu tương đồng):

```text
Bạn là chuyên gia chuyển đổi ngôn ngữ tự nhiên thành câu lệnh SQL cho cơ sở dữ liệu CRM.
Nhiệm vụ: Dịch câu hỏi tiếng Việt của người dùng thành duy nhất một câu lệnh SQL chính xác, an toàn và tối ưu.

=== 1. NGỮ CẢNH HỆ THỐNG ===
- Thời gian hiện tại: {current_timestamp}
- Mốc ngày hôm nay: {current_date}
- Năm hiện tại: {current_year}, Quý hiện tại: {current_quarter}

=== 2. LƯỢC ĐỒ CƠ SỞ DỮ LIỆU ĐƯỢC CHỌN LỌC ===
Table: customers (Khách hàng)
- customer_id: INT, Khóa chính
- customer_name: VARCHAR, Tên khách hàng hoặc tên công ty
- customer_type: VARCHAR, Loại khách hàng: 'B2B' (Doanh nghiệp) hoặc 'B2C' (Cá nhân)
- city: VARCHAR, Tỉnh/Thành phố

Table: orders (Đơn hàng)
- order_id: INT, Khóa chính
- customer_id: INT, Khóa ngoại nối với customers.customer_id
- total_amount: DECIMAL, Tổng tiền đơn hàng
- status: VARCHAR, Trạng thái: 'COMPLETED' (Hoàn thành), 'CANCELLED' (Hủy), 'PENDING' (Chờ thanh toán)
- created_at: TIMESTAMP, Ngày tạo đơn

Table: order_items (Chi tiết đơn hàng)
- item_id: INT, Khóa chính
- order_id: INT, Khóa ngoại nối với orders.order_id
- product_id: INT, Khóa ngoại nối với products.product_id
- quantity: INT, Số lượng mua
- unit_price: DECIMAL, Đơn giá lúc bán

Table: products (Sản phẩm)
- product_id: INT, Khóa chính
- product_name: VARCHAR, Tên sản phẩm
- category: VARCHAR, Nhóm sản phẩm

Quan hệ liên kết (JOIN Relations):
- customers.customer_id = orders.customer_id
- orders.order_id = order_items.order_id
- order_items.product_id = products.product_id

=== 3. CÁC QUY TẮC NGHIỆP VỤ BẮT BUỘC ===
1. Khi tính Doanh thu / Doanh số, chỉ tính các đơn hàng có trạng thái thành công: orders.status = 'COMPLETED'.
2. Tìm kiếm chuỗi ký tự (tên, địa phương) phải không phân biệt hoa thường bằng hàm LOWER() hoặc ILIKE.
3. Không tự ý viết câu lệnh DDL/DML (chỉ dùng SELECT).
4. Nếu câu hỏi yêu cầu xếp hạng (Top N), bắt buộc dùng ORDER BY ... DESC LIMIT N. Nếu không nói rõ số lượng, luôn thêm LIMIT 50.
5. Chỉ sử dụng các cột đã được liệt kê ở trên, tuyệt đối không suy diễn cột mới.
6. Chỉ trả về mã SQL, không giải thích thêm.

=== 4. VÍ DỤ THAM KHẢO CÙNG KHUNG XƯƠNG ===
{retrieved_few_shot_examples}

=== 5. CÂU HỎI NGƯỜI DÙNG CẦN CHUYỂN ĐỔI ===
Câu hỏi: "{user_question}"
SQL:
```

---

## 6. HƯỚNG DẪN TRIỂN KHAI TỪNG BƯỚC (STEP-BY-STEP IMPLEMENTATION ROADMAP)

Để đưa hệ thống vào vận hành thực tế đạt độ chính xác >85% mà không cần GPU, dự án triển khai qua 4 giai đoạn rõ ràng:

### Giai đoạn 1: Chuẩn bị Siêu dữ liệu (Metadata) & Từ điển Nghiệp vụ
1. **Trích xuất lược đồ sạch**: Xuất danh sách bảng, cột, kiểu dữ liệu và mối quan hệ Khóa chính - Khóa ngoại của hệ thống CRM.
2. **Gắn nhãn tiếng Việt**: Bổ sung chú thích (Comment) cho từng cột bằng tiếng Việt thân thuộc với đội Sales (ví dụ: `total_amount` $\to$ *"tổng tiền sau thuế và chiết khấu"*).
3. **Cấu hình Từ điển đồng nghĩa**: Khai báo bảng ánh xạ các từ viết tắt và tiếng lóng nội bộ công ty (B2B, B2C, chốt deal, tiền về).

### Giai đoạn 2: Xây dựng Bộ Điều Phối trên CPU (Orchestration Engine)
1. **Lập trình luồng tiền xử lý (Stage 1 & 2)**:
   * Module chuẩn hóa thời gian và phương ngữ.
   * Module tính điểm từ khóa để lọc top 3-5 bảng liên quan nhất.
   * Module duyệt đồ thị khóa ngoại để tự động điền bảng trung gian.
2. **Xây dựng kho mẫu Golden SQL ban đầu**:
   * Chuẩn bị 50 cặp câu hỏi - câu lệnh SQL mẫu bao phủ đủ 3 mức độ (Đơn giản, Trung bình, Phức tạp).
   * Gắn nhãn "khung xương cú pháp" cho từng câu mẫu để phục vụ việc chọn lọc theo DAIL-SQL.

### Giai đoạn 3: Kết nối Black-Box LLM & Vòng lặp Sửa Lỗi (Pattern IV & V)
1. **Tạo tài khoản Read-Only trên CRM**:
   * Khởi tạo tài khoản người dùng riêng biệt trên cơ sở dữ liệu Read-Replica, chỉ cấp quyền `SELECT`.
   * Cấu hình giới hạn bộ nhớ (`work_mem = 16MB`) và thời gian ngắt lệnh (`statement_timeout = 3000ms`).
2. **Cài đặt cơ chế tự sửa lỗi**:
   * Nhận câu SQL từ LLM $\to$ chạy lệnh `EXPLAIN` kiểm tra.
   * Nếu có lỗi: Dịch thông báo lỗi của cơ sở dữ liệu sang ngôn ngữ dễ hiểu $\to$ gọi lại LLM sửa (giới hạn tối đa 2 lần lặp).

### Giai đoạn 4: Đánh giá & Giám sát vận hành
1. **Kiểm thử tự động trên tập mẫu (Benchmark Test)**:
   * Chạy tự động toàn bộ 50 câu hỏi mẫu qua hệ thống.
   * So sánh kết quả dữ liệu trả về giữa câu SQL chuẩn và câu SQL do AI sinh ra. Tinh chỉnh từ điển nếu độ chính xác chưa đạt 85%.
2. **Ghi nhật ký (Logging) & Học liên tục**:
   * Mọi câu hỏi người dùng nhập và câu lệnh SQL sinh ra đều được lưu lại.
   * Các câu hỏi mà nhân viên CSKH/Sales đánh giá "kết quả chính xác" sẽ được quản trị viên duyệt để bổ sung trực tiếp vào kho Golden SQL, giúp hệ thống ngày càng thông minh hơn theo thời gian mà không cần đào tạo lại mô hình.