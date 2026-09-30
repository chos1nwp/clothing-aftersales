package com.example.aftersales.mapper;

import com.example.aftersales.entity.WarehouseRecordDO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.Collection;
import java.util.List;

@Mapper
public interface WarehouseMapper {

    WarehouseRecordDO findByAftersalesId(@Param("aftersalesId") long aftersalesId);

    /** 工作台列表用：一次取回本页所有单据的仓库记录，避免逐行查询 */
    List<WarehouseRecordDO> findByAftersalesIds(@Param("ids") Collection<Long> ids);

    int insert(WarehouseRecordDO record);

    int updateReceipt(WarehouseRecordDO record);

    int updateInspection(WarehouseRecordDO record);
}
