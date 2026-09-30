package com.example.aftersales.mapper;

import com.example.aftersales.entity.WarehouseRecordDO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface WarehouseMapper {

    WarehouseRecordDO findByAftersalesId(@Param("aftersalesId") long aftersalesId);

    int insert(WarehouseRecordDO record);

    int updateReceipt(WarehouseRecordDO record);

    int updateInspection(WarehouseRecordDO record);
}
