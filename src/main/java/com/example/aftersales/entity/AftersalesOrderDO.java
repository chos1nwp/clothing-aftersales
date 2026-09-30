package com.example.aftersales.entity;

import com.example.aftersales.domain.AftersalesStatus;
import com.example.aftersales.domain.AftersalesType;
import com.example.aftersales.domain.ReasonCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class AftersalesOrderDO {

    private long id;
    private String aftersalesNo;
    private long orderItemId;
    private long consumerUserId;
    private AftersalesType type;
    private ReasonCode reasonCode;
    private int quantity;
    private String description;
    private AftersalesStatus status;
    private String returnGuidance;
    private String consumerParcelNo;
    private BigDecimal refundAmount;
    private String resendTrackingNo;
    private String finalNote;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime closedAt;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getAftersalesNo() { return aftersalesNo; }
    public void setAftersalesNo(String aftersalesNo) { this.aftersalesNo = aftersalesNo; }
    public long getOrderItemId() { return orderItemId; }
    public void setOrderItemId(long orderItemId) { this.orderItemId = orderItemId; }
    public long getConsumerUserId() { return consumerUserId; }
    public void setConsumerUserId(long consumerUserId) { this.consumerUserId = consumerUserId; }
    public AftersalesType getType() { return type; }
    public void setType(AftersalesType type) { this.type = type; }
    public ReasonCode getReasonCode() { return reasonCode; }
    public void setReasonCode(ReasonCode reasonCode) { this.reasonCode = reasonCode; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public AftersalesStatus getStatus() { return status; }
    public void setStatus(AftersalesStatus status) { this.status = status; }
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
}
