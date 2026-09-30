package com.example.aftersales.controller;

import com.example.aftersales.common.ApiResponse;
import com.example.aftersales.domain.UserRole;
import com.example.aftersales.common.RequireRole;
import com.example.aftersales.dto.OrderView;
import com.example.aftersales.service.AftersalesQueryService;
import com.example.aftersales.service.AuthService;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/consumer")
@RequireRole(UserRole.CONSUMER)
public class ConsumerOrderController {

    private final AftersalesQueryService queryService;
    private final AuthService authService;

    public ConsumerOrderController(AftersalesQueryService queryService, AuthService authService) {
        this.queryService = queryService;
        this.authService = authService;
    }

    @GetMapping("/orders")
    public ApiResponse<List<OrderView>> orders(HttpSession session) {
        return ApiResponse.ok(queryService.consumerOrders(authService.requireLogin(session)));
    }
}
