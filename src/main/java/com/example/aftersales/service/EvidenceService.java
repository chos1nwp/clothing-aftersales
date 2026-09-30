package com.example.aftersales.service;

import com.example.aftersales.common.BizException;
import com.example.aftersales.entity.EvidenceDO;
import com.example.aftersales.mapper.EvidenceMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/**
 * 图片凭证存储。文件名一律重新生成 UUID，不使用用户提交的原始文件名拼接路径。
 */
@Service
public class EvidenceService {

    private static final Set<String> ALLOWED_EXT = Set.of("jpg", "jpeg", "png", "webp", "gif");

    private final EvidenceMapper evidenceMapper;
    private final Path uploadRoot;
    private final long maxBytes;
    private final int maxCount;

    public EvidenceService(EvidenceMapper evidenceMapper,
                           @Value("${app.upload-dir}") String uploadDir,
                           @Value("${app.max-upload-size-bytes}") long maxBytes,
                           @Value("${app.max-evidence-count}") int maxCount) {
        this.evidenceMapper = evidenceMapper;
        this.uploadRoot = Paths.get(uploadDir).toAbsolutePath().normalize();
        this.maxBytes = maxBytes;
        this.maxCount = maxCount;
    }

    public EvidenceDO save(long aftersalesId, MultipartFile file, long uploaderId) {
        if (file == null || file.isEmpty()) {
            throw BizException.badRequest("请选择要上传的图片");
        }
        if (file.getSize() > maxBytes) {
            throw BizException.badRequest("单张图片不能超过 " + (maxBytes / 1024 / 1024) + "MB");
        }
        if (evidenceMapper.countByAftersalesId(aftersalesId) >= maxCount) {
            throw BizException.badRequest("一张售后单最多上传 " + maxCount + " 张图片");
        }

        String ext = extensionOf(file.getOriginalFilename());
        if (!ALLOWED_EXT.contains(ext)) {
            throw BizException.badRequest("只支持 jpg / png / webp / gif 格式的图片");
        }

        String storedName = UUID.randomUUID().toString().replace("-", "") + "." + ext;
        try {
            Files.createDirectories(uploadRoot);
            try (var input = file.getInputStream()) {
                Files.copy(input, uploadRoot.resolve(storedName), StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            throw new IllegalStateException("图片保存失败", e);
        }

        EvidenceDO evidence = new EvidenceDO();
        evidence.setAftersalesId(aftersalesId);
        evidence.setFilePath("uploads/" + storedName);
        evidence.setOriginalName(sanitizeName(file.getOriginalFilename()));
        evidence.setUploadedBy(uploaderId);
        evidenceMapper.insert(evidence);
        return evidence;
    }

    public List<EvidenceDO> list(long aftersalesId) {
        return evidenceMapper.findByAftersalesId(aftersalesId);
    }

    private String extensionOf(String originalName) {
        if (originalName == null) {
            return "";
        }
        int dot = originalName.lastIndexOf('.');
        return dot < 0 ? "" : originalName.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private String sanitizeName(String originalName) {
        if (originalName == null) {
            return "image";
        }
        String name = Paths.get(originalName).getFileName().toString();
        return name.length() > 120 ? name.substring(0, 120) : name;
    }
}
