package com.example.aftersales.controller;

import com.example.aftersales.common.ApiResponse;
import com.example.aftersales.common.RequireRole;
import com.example.aftersales.domain.UserRole;
import com.example.aftersales.dto.ApplyRequest;
import com.example.aftersales.dto.MarkShippedRequest;
import com.example.aftersales.dto.ResubmitRequest;
import com.example.aftersales.service.AftersalesFlowService;
import com.example.aftersales.service.AftersalesQueryService;
import com.example.aftersales.service.AuthService;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/aftersales")
public class AftersalesController {

    private final AftersalesFlowService flowService;
    private final AftersalesQueryService queryService;
    private final AuthService authService;

    public AftersalesController(AftersalesFlowService flowService,
                                AftersalesQueryService queryService,
                                AuthService authService) {
        this.flowService = flowService;
        this.queryService = queryService;
        this.authService = authService;
    }

    @PostMapping
    @RequireRole(UserRole.CONSUMER)
    public ApiResponse<Long> apply(@Valid @RequestBody ApplyRequest request, HttpSession session) {
        long id = flowService.apply(authService.requireLogin(session), request);
        return ApiResponse.ok(id);
    }

    @GetMapping("/mine")
    @RequireRole(UserRole.CONSUMER)
    public ApiResponse<Object> mine(@RequestParam(required = false) String status, HttpSession session) {
        return ApiResponse.ok(queryService.myAftersales(authService.requireLogin(session), status));
    }

    @PostMapping("/{id}/evidence")
    @RequireRole(UserRole.CONSUMER)
    public ApiResponse<Void> uploadEvidence(@PathVariable long id,
                                            @RequestPart("file") MultipartFile file,
                                            HttpSession session) {
        flowService.uploadEvidence(authService.requireLogin(session), id, file);
        return ApiResponse.ok(null);
    }

    @PostMapping("/{id}/resubmit")
    @RequireRole(UserRole.CONSUMER)
    public ApiResponse<Void> resubmit(@PathVariable long id,
                                      @Valid @RequestBody ResubmitRequest request,
                                      HttpSession session) {
        flowService.resubmit(authService.requireLogin(session), id, request);
        return ApiResponse.ok(null);
    }

    @PostMapping("/{id}/mark-shipped")
    @RequireRole(UserRole.CONSUMER)
    public ApiResponse<Void> markShipped(@PathVariable long id,
                                         @Valid @RequestBody MarkShippedRequest request,
                                         HttpSession session) {
        flowService.markShipped(authService.requireLogin(session), id, request);
        return ApiResponse.ok(null);
    }

    @PostMapping("/{id}/cancel")
    @RequireRole(UserRole.CONSUMER)
    public ApiResponse<Void> cancel(@PathVariable long id, HttpSession session) {
        flowService.cancel(authService.requireLogin(session), id);
        return ApiResponse.ok(null);
    }

    /** 三角色共用，消费者只能看到本人单据，且时间线只含对外说明 */
    @GetMapping("/{id}")
    public ApiResponse<Object> detail(@PathVariable long id, HttpSession session) {
        return ApiResponse.ok(queryService.detail(authService.requireLogin(session), id));
    }
}
