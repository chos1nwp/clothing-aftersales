package com.example.aftersales.entity;

import java.time.LocalDateTime;

public class EvidenceDO {

    private long id;
    private long aftersalesId;
    private String filePath;
    private String originalName;
    private long uploadedBy;
    private LocalDateTime createdAt;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public long getAftersalesId() { return aftersalesId; }
    public void setAftersalesId(long aftersalesId) { this.aftersalesId = aftersalesId; }
    public String getFilePath() { return filePath; }
    public void setFilePath(String filePath) { this.filePath = filePath; }
    public String getOriginalName() { return originalName; }
    public void setOriginalName(String originalName) { this.originalName = originalName; }
    public long getUploadedBy() { return uploadedBy; }
    public void setUploadedBy(long uploadedBy) { this.uploadedBy = uploadedBy; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
