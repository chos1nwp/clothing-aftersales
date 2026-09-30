package com.example.aftersales.mapper;

import com.example.aftersales.entity.EvidenceDO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface EvidenceMapper {

    int insert(EvidenceDO record);

    List<EvidenceDO> findByAftersalesId(@Param("aftersalesId") long aftersalesId);

    int countByAftersalesId(@Param("aftersalesId") long aftersalesId);
}
