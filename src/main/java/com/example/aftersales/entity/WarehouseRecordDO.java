package com.example.aftersales.entity;

import java.time.LocalDateTime;

public class WarehouseRecordDO {

    private long id;
    private long aftersalesId;
    private String parcelNo;
    private LocalDateTime receivedAt;
    private Long receivedBy;
    private String inspectionResult;
    private String issueDescription;
    private LocalDateTime inspectedAt;
    private Long inspectedBy;

    public boolean isReceived() {
        return receivedAt != null;
    }

    public boolean isInspected() {
        return inspectionResult != null;
    }

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public long getAftersalesId() { return aftersalesId; }
    public void setAftersalesId(long aftersalesId) { this.aftersalesId = aftersalesId; }
    public String getParcelNo() { return parcelNo; }
    public void setParcelNo(String parcelNo) { this.parcelNo = parcelNo; }
    public LocalDateTime getReceivedAt() { return receivedAt; }
    public void setReceivedAt(LocalDateTime receivedAt) { this.receivedAt = receivedAt; }
    public Long getReceivedBy() { return receivedBy; }
    public void setReceivedBy(Long receivedBy) { this.receivedBy = receivedBy; }
    public String getInspectionResult() { return inspectionResult; }
    public void setInspectionResult(String inspectionResult) { this.inspectionResult = inspectionResult; }
    public String getIssueDescription() { return issueDescription; }
    public void setIssueDescription(String issueDescription) { this.issueDescription = issueDescription; }
    public LocalDateTime getInspectedAt() { return inspectedAt; }
    public void setInspectedAt(LocalDateTime inspectedAt) { this.inspectedAt = inspectedAt; }
    public Long getInspectedBy() { return inspectedBy; }
    public void setInspectedBy(Long inspectedBy) { this.inspectedBy = inspectedBy; }
}
