package com.example.aftersales.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 客服审核动作：APPROVE_RETURN / NEED_SUPPLEMENT / REJECT。
 */
public record ReviewRequest(
        @NotBlank(message = "请选择审核动作")
        String action,

        String note,

        String returnGuidance
) {
}
