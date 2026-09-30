package com.example.aftersales.controller;

import com.example.aftersales.common.ApiResponse;
import com.example.aftersales.common.RequireRole;
import com.example.aftersales.domain.UserRole;
import com.example.aftersales.dto.FinalizeRequest;
import com.example.aftersales.dto.InspectRequest;
import com.example.aftersales.dto.ReceiveRequest;
import com.example.aftersales.dto.ReviewRequest;
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
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/staff/aftersales")
@RequireRole({UserRole.CS, UserRole.WAREHOUSE})
public class StaffAftersalesController {

    private final AftersalesFlowService flowService;
    private final AftersalesQueryService queryService;
    private final AuthService authService;

    public StaffAftersalesController(AftersalesFlowService flowService,
                                     AftersalesQueryService queryService,
                                     AuthService authService) {
        this.flowService = flowService;
        this.queryService = queryService;
        this.authService = authService;
    }

    @GetMapping
    public ApiResponse<Object> list(@RequestParam(required = false) String status,
                                    @RequestParam(required = false) String type,
                                    @RequestParam(required = false) String keyword) {
        return ApiResponse.ok(queryService.staffList(status, type, keyword));
    }

    @GetMapping("/stats")
    public ApiResponse<Object> stats() {
        return ApiResponse.ok(queryService.statusCounts());
    }

    @GetMapping("/{id}/timeline")
    public ApiResponse<Object> timeline(@PathVariable long id, HttpSession session) {
        var user = authService.requireLogin(session);
        return ApiResponse.ok(queryService.detail(user, id).getTimeline());
    }

    @PostMapping("/{id}/review")
    @RequireRole(UserRole.CS)
    public ApiResponse<Void> review(@PathVariable long id,
                                    @Valid @RequestBody ReviewRequest request,
                                    HttpSession session) {
        flowService.review(authService.requireLogin(session), id, request);
        return ApiResponse.ok(null);
    }

    @PostMapping("/{id}/finalize")
    @RequireRole(UserRole.CS)
    public ApiResponse<Void> finalizeReview(@PathVariable long id,
                                            @Valid @RequestBody FinalizeRequest request,
                                            HttpSession session) {
        flowService.finalize(authService.requireLogin(session), id, request);
        return ApiResponse.ok(null);
    }

    @PostMapping("/{id}/receive")
    @RequireRole(UserRole.WAREHOUSE)
    public ApiResponse<Void> receive(@PathVariable long id,
                                     @Valid @RequestBody ReceiveRequest request,
                                     HttpSession session) {
        flowService.receive(authService.requireLogin(session), id, request);
        return ApiResponse.ok(null);
    }

    @PostMapping("/{id}/inspect")
    @RequireRole(UserRole.WAREHOUSE)
    public ApiResponse<Void> inspect(@PathVariable long id,
                                     @Valid @RequestBody InspectRequest request,
                                     HttpSession session) {
        flowService.inspect(authService.requireLogin(session), id, request);
        return ApiResponse.ok(null);
    }
}
