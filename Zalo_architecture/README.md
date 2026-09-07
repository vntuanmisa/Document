# Bộ Hồ Sơ Kiến Trúc Giải Pháp: AI Khám Phá Khách Hàng Từ Hội Thoại Zalo
**Tích hợp hệ sinh thái MISA AMIS CRM (`https://misajsc.amis.vn/crm`)**

Bộ tài liệu kiến trúc toàn diện được biên soạn theo chuẩn quốc tế **C4 Model** (4 cấp độ) kết hợp sơ đồ luồng quy trình (Workflows), sơ đồ ca sử dụng (Use Case Diagram) và đặc tả Ingestion API chuẩn OpenAPI 3.0.

> **Tài liệu chủ đạo**: Hãy xem [TOAN_BO_GIAI_PHAP_KIEN_TRUC.md](file:///d:/Github/Zalo_ext/docs/architecture/TOAN_BO_GIAI_PHAP_KIEN_TRUC.md) để nắm toàn bộ bức tranh kiến trúc, vai trò của AI Engine, quy tắc bóc tách MST/CCCD và prompt 7 mục khám phá khách hàng.

---

## 1. Danh Mục Sơ Đồ Kiến Trúc C4 (4 Cấp Độ)

| Cấp Độ C4 | Loại Sơ Đồ | File Đồ Họa Tương Tác | File Nguồn / Đặc Tả |
| :--- | :--- | :--- | :--- |
| **C4 Level 1** | **System Context** (Bối cảnh hệ thống tổng thể) | [c4-level1-context.html](file:///d:/Github/Zalo_ext/docs/architecture/c4-level1-context.html) | [c4-level1-context.architecture.json](file:///d:/Github/Zalo_ext/docs/architecture/c4-level1-context.architecture.json) |
| **C4 Level 2** | **Container Diagram** (Ứng dụng & Dịch vụ toàn hệ thống) | [c4-level2-container.html](file:///d:/Github/Zalo_ext/docs/architecture/c4-level2-container.html) | [c4-level2-container.architecture.json](file:///d:/Github/Zalo_ext/docs/architecture/c4-level2-container.architecture.json) |
| **C4 Level 3 (AI Core)** | **Component Diagram** (Chi tiết Engine AI & Bóc tách MST) | [c4-level3-ai-core.html](file:///d:/Github/Zalo_ext/docs/architecture/c4-level3-ai-core.html) | [c4-level3-ai-core.architecture.json](file:///d:/Github/Zalo_ext/docs/architecture/c4-level3-ai-core.architecture.json) |
| **C4 Level 4** | **Code & Detailed Design** (Thiết kế lớp đối tượng & luồng hàm) | Nằm trong mục 2.4 của [TOAN_BO_GIAI_PHAP_KIEN_TRUC.md](file:///d:/Github/Zalo_ext/docs/architecture/TOAN_BO_GIAI_PHAP_KIEN_TRUC.md) | Mermaid Class/Sequence |

---

## 2. Danh Mục Sơ Đồ Luồng Dữ Liệu & Quy Trình (Sequence Swimlanes)

| Tên Quy Trình | Nội Dung & Ý Nghĩa | File Đồ Họa Tương Tác | File Nguồn JSON |
| :--- | :--- | :--- | :--- |
| **End-to-End Pipeline** | Sequence Swimlane 8 Lifelines: Zalo Web $\rightarrow$ Extension $\rightarrow$ Ingest API $\rightarrow$ Kafka $\rightarrow$ AI $\rightarrow$ Local LLM $\rightarrow$ MISA AMIS CRM | [flow-end-to-end-pipeline.html](file:///d:/Github/Zalo_ext/docs/architecture/flow-end-to-end-pipeline.html) | [flow-end-to-end-pipeline.sequence.json](file:///d:/Github/Zalo_ext/docs/architecture/flow-end-to-end-pipeline.sequence.json) |
| **AI Discovery Workflow** | Sequence Swimlane 7 Lifelines: Kafka $\rightarrow$ Gom Cặp $\rightarrow$ Bóc Tách MST/CCCD $\rightarrow$ Lắp Prompt $\rightarrow$ Local LLM $\rightarrow$ Guardrail $\rightarrow$ AMIS CRM | [flow-ai-discovery-process.html](file:///d:/Github/Zalo_ext/docs/architecture/flow-ai-discovery-process.html) | [flow-ai-discovery-process.sequence.json](file:///d:/Github/Zalo_ext/docs/architecture/flow-ai-discovery-process.sequence.json) |
| **Extension Capture Workflow** | Sequence Swimlane 5 Lifelines: NVKD $\rightarrow$ Extension Popup $\rightarrow$ Content Script (DOM) $\rightarrow$ Background Worker $\rightarrow$ Ingestion API | [flow-extension-capture.html](file:///d:/Github/Zalo_ext/docs/architecture/flow-extension-capture.html) | [flow-extension-capture.sequence.json](file:///d:/Github/Zalo_ext/docs/architecture/flow-extension-capture.sequence.json) |

---

## 3. Đặc Tả Ingestion API (Domain: `https://misajsc.amis.vn/crm`)

- **Phương thức xác thực**: Bắt buộc qua Header: `Authorization: Bearer <token>`.
- **Tài liệu hướng dẫn Markdown**: [api-ingestion-amis.md](file:///d:/Github/Zalo_ext/docs/architecture/api-ingestion-amis.md)
- **Đặc tả OpenAPI 3.0**: [api-ingestion-amis.yaml](file:///d:/Github/Zalo_ext/docs/architecture/api-ingestion-amis.yaml)
