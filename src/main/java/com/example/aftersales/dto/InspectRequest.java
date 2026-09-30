package com.example.aftersales.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 仓库验货结果：PASS / ABNORMAL。异常必须写清现象。
 */
public record InspectRequest(
        @NotBlank(message = "请选择验货结果")
        String result,

        String issueDescription
) {
}
