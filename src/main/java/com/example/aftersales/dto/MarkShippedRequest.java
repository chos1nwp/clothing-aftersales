package com.example.aftersales.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record MarkShippedRequest(
        @NotBlank(message = "请填写寄回包裹号")
        @Size(max = 64, message = "包裹号过长")
        String parcelNo
) {
}
