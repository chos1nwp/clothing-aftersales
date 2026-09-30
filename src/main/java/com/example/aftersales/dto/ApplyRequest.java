package com.example.aftersales.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ApplyRequest(
        @NotNull(message = "请选择要申请售后的商品")
        Long orderItemId,

        @NotBlank(message = "请选择售后类型")
        String type,

        @NotNull(message = "请填写申请数量")
        @Min(value = 1, message = "申请数量至少为 1")
        Integer quantity,

        @NotBlank(message = "请选择申请原因")
        String reasonCode,

        @NotBlank(message = "请填写情况说明")
        @Size(min = 5, max = 500, message = "情况说明至少 5 个字，请描述具体现象")
        String description
) {
}
