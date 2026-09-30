package com.example.aftersales.dto;

import com.example.aftersales.entity.ActionLogDO;
import com.example.aftersales.entity.EvidenceDO;
import com.example.aftersales.entity.WarehouseRecordDO;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 售后单视图：列表用基础字段，详情额外带仓库记录、凭证和时间线。
 */
public class AftersalesView {

    private long id;
    private String aftersalesNo;
    private String type;
    private String typeLabel;
    private String reasonCode;
    private String reasonLabel;
    private int quantity;
    private String description;
    private String status;
    private String statusLabel;
    private String returnGuidance;
    private String consumerParcelNo;
    private BigDecimal refundAmount;
    private String resendTrackingNo;
    private String finalNote;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime closedAt;

    private long orderItemId;
    private String productName;
    private String color;
    private String size;
    private BigDecimal unitPrice;
    private int itemQuantity;
    private String orderNo;
    private LocalDateTime orderCompletedAt;
    private LocalDateTime afterSaleDeadline;

    private long consumerUserId;
    private String consumerName;

    private WarehouseRecordDO warehouseRecord;
    private List<EvidenceDO> evidenceList;
    private List<ActionLogDO> timeline;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getAftersalesNo() { return aftersalesNo; }
    public void setAftersalesNo(String aftersalesNo) { this.aftersalesNo = aftersalesNo; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public String getTypeLabel() { return typeLabel; }
    public void setTypeLabel(String typeLabel) { this.typeLabel = typeLabel; }
    public String getReasonCode() { return reasonCode; }
    public void setReasonCode(String reasonCode) { this.reasonCode = reasonCode; }
    public String getReasonLabel() { return reasonLabel; }
    public void setReasonLabel(String reasonLabel) { this.reasonLabel = reasonLabel; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getStatusLabel() { return statusLabel; }
    public void setStatusLabel(String statusLabel) { this.statusLabel = statusLabel; }
    public String getReturnGuidance() { return returnGuidance; }
    public void setReturnGuidance(String returnGuidance) { this.returnGuidance = returnGuidance; }
    public String getConsumerParcelNo() { return consumerParcelNo; }
    public void setConsumerParcelNo(String consumerParcelNo) { this.consumerParcelNo = consumerParcelNo; }
    public BigDecimal getRefundAmount() { return refundAmount; }
    public void setRefundAmount(BigDecimal refundAmount) { this.refundAmount = refundAmount; }
    public String getResendTrackingNo() { return resendTrackingNo; }
    public void setResendTrackingNo(String resendTrackingNo) { this.resendTrackingNo = resendTrackingNo; }
    public String getFinalNote() { return finalNote; }
    public void setFinalNote(String finalNote) { this.finalNote = finalNote; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
    public LocalDateTime getClosedAt() { return closedAt; }
    public void setClosedAt(LocalDateTime closedAt) { this.closedAt = closedAt; }
    public long getOrderItemId() { return orderItemId; }
    public void setOrderItemId(long orderItemId) { this.orderItemId = orderItemId; }
    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }
    public String getColor() { return color; }
    public void setColor(String color) { this.color = color; }
    public String getSize() { return size; }
    public void setSize(String size) { this.size = size; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public void setUnitPrice(BigDecimal unitPrice) { this.unitPrice = unitPrice; }
    public int getItemQuantity() { return itemQuantity; }
    public void setItemQuantity(int itemQuantity) { this.itemQuantity = itemQuantity; }
    public String getOrderNo() { return orderNo; }
    public void setOrderNo(String orderNo) { this.orderNo = orderNo; }
    public LocalDateTime getOrderCompletedAt() { return orderCompletedAt; }
    public void setOrderCompletedAt(LocalDateTime orderCompletedAt) { this.orderCompletedAt = orderCompletedAt; }
    public LocalDateTime getAfterSaleDeadline() { return afterSaleDeadline; }
    public void setAfterSaleDeadline(LocalDateTime afterSaleDeadline) { this.afterSaleDeadline = afterSaleDeadline; }
    public long getConsumerUserId() { return consumerUserId; }
    public void setConsumerUserId(long consumerUserId) { this.consumerUserId = consumerUserId; }
    public String getConsumerName() { return consumerName; }
    public void setConsumerName(String consumerName) { this.consumerName = consumerName; }
    public WarehouseRecordDO getWarehouseRecord() { return warehouseRecord; }
    public void setWarehouseRecord(WarehouseRecordDO warehouseRecord) { this.warehouseRecord = warehouseRecord; }
    public List<EvidenceDO> getEvidenceList() { return evidenceList; }
    public void setEvidenceList(List<EvidenceDO> evidenceList) { this.evidenceList = evidenceList; }
    public List<ActionLogDO> getTimeline() { return timeline; }
    public void setTimeline(List<ActionLogDO> timeline) { this.timeline = timeline; }
}
