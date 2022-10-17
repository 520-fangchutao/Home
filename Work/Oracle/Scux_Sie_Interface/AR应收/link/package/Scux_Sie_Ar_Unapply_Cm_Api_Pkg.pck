CREATE OR REPLACE PACKAGE Scux_Sie_Ar_Unapply_Cm_Api_Pkg AS

  /*=============================================================
  Copyright (C)  SIE Consulting Co., Ltd    
  All rights reserved 
  ===============================================================
  Program Name:   Scux_Sie_Ar_Unapply_Cm_Api_Pkg
  Author      :   SIE 谭家俊
  Created:    :   2018-09-18
  Purpose     :   
  Description : 应收贷项发票取消核销API
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0     2018-09-18    SIE 谭家俊        Creation
  V1.1     2018-12-17    SIE 郭剑          标准化修改
  V1.2        2019-03-12    SIE张可盈      Do_Import方法添加Pv_Created_by参数与
  ===============================================================*/

  /*===============================================================
  Program Name:   Do_Import
  Author      :   SIE 谭家俊
  Created:   :    2018-09-18
  Purpose     :  应收贷项发票取消核销API
  
  Parameters  :
              Pt_Iface_Tbl         IN SCUX_SIE_AR_UNAPP_CM_TBL --AR取消CM核销信息
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Synchro_Flag      IN VARCHAR2 --同步还是异步调用方式
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
              Pv_Language          IN VARCHAR2 --语言
  Return  :
              Xn_Scux_Session_Id   OUT NUMBER  --批次ID
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 应收贷项发票取消核销API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-07-25    SIE 谭家俊         Creation    
  V1.1     2018-12-17    SIE 郭剑          标准化修改
    V1.2        2019-03-12    SIE张可盈      Do_Import方法添加Pv_Created_by参数与
  ===============================================================*/
  PROCEDURE Do_Import(Pt_Iface_Tbl        IN Scux_Sie_Ar_Unapp_Cm_Tbl
                     ,Pv_Scux_Source_Code IN VARCHAR2
                     ,Pv_Synchro_Flag     IN VARCHAR2 DEFAULT 'Y' -- 是否同步调用
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'N' --V1.1 'Y' --是否初始化环境
                     ,Pv_Language         IN VARCHAR2 DEFAULT 'ZHS'
                     ,Xn_Scux_Session_Id  OUT NUMBER
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2
                     ,Pv_Created_By       IN VARCHAR2 DEFAULT NULL --V1.2 MOD
                      
                      );

END Scux_Sie_Ar_Unapply_Cm_Api_Pkg;
/
CREATE OR REPLACE PACKAGE BODY Scux_Sie_Ar_Unapply_Cm_Api_Pkg AS

  Gv_Package_Name CONSTANT VARCHAR2(30) := 'Scux_Sie_Ar_Unapply_Cm_Api_Pkg';
  Gv_Pending      CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Pending; -- 'PENDING'; --待定
  --Gv_Running      CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Running; -- 'RUNNING'; --运行中
  --Gv_Submit       CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Submit; -- 'SUBMIT'; --已提交(用于异步调用并发请求中间状态
  --Gv_Completed    CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Completed; -- 'COMPLETED'; --已完成
  Gv_Error CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Error; -- 'ERROR'; --错误

  Gv_Date_Type CONSTANT VARCHAR2(20) := 'SOA';

  Gv_Application_Code CONSTANT VARCHAR2(30) := Scux_Fnd_Log.Gv_Application_Code; --ADD BY SIE 谭家俊 2018/8/31
  --v1.2    ADD   START--
  Gn_User_Id NUMBER := Fnd_Global.User_Id; --登录ERP账号ID
  --V1.2    ADD    END-
  /*===============================================================
  Program Name:    Get_Scux_Interface_Header_Id
  Author      :   SIE 谭家俊
  Created:    :   2018-07-01
  Purpose     :   主从表获取主表的头ID
  Parameters  :
               pn_Scux_Session_Id          IN NUMBER --日记帐类信息
               pv_Scux_Source_Code         IN VARCHAR2--数据来源
               pv_Scux_Source_Num          IN VARCHAR2 --来源编号
  Return  :
              Xn_Scux_Interface_Header_IdOUT NUMBER --主表header_id
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 主从表获取主表的头ID
  有主从关系的两组对像以Scux_Source_Code，Scux_Source_Num建立主从关联
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-18    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Get_Scux_Interface_Header_Id(Pn_Scux_Session_Id          IN NUMBER
                                        ,Pv_Scux_Source_Code         IN VARCHAR2
                                        ,Pv_Scux_Source_Num          IN VARCHAR2
                                        ,Xn_Scux_Interface_Header_Id OUT NUMBER
                                        ,Xv_Ret_Status               OUT VARCHAR2
                                        ,Xv_Ret_Message              OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Get_Scux_Interface_Header_Id';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    SELECT h.Scux_Interface_Header_Id
      INTO Xn_Scux_Interface_Header_Id
      FROM Scux_Sie_Ar_Unapp_Cm_Iface h
     WHERE h.Scux_Source_Code = Pv_Scux_Source_Code
       AND h.Scux_Source_Num = Pv_Scux_Source_Num
       AND h.Scux_Session_Id = Pn_Scux_Session_Id;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Get_Scux_Interface_Header_Id;

  /*===============================================================
  Program Name:   Validate_Data
  Author      :   SIE 谭家俊
  Created:    :   2018-07-01
  Purpose     :   验证必输入字段不能为空
  Parameters  :
              Pt_Iface_Tbl         IN Scux_Sie_Gl_Journal_Tbl --日记帐类信息
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 验证必输入字段不能为空
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-18    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Validate_Data(Pt_Iface_Tbl        IN Scux_Sie_Ar_Unapp_Cm_Tbl
                         ,Pv_Scux_Source_Code IN VARCHAR
                         ,Xv_Ret_Status       OUT VARCHAR2
                         ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Date';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pv_Scux_Source_Code IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Scux_Source_Code');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    
    END IF;
  
    FOR i IN Pt_Iface_Tbl.First .. Pt_Iface_Tbl.Last LOOP
      --SCUX_SOURCE_NUM 为必输项
      IF Pt_Iface_Tbl(i).Scux_Source_Num IS NULL THEN
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                       ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                       ,Pv_Token1           => '1'
                                                       ,Pv_Value1           => 'SCUX_SOURCE_NUM');
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Xv_Ret_Status
                                      ,Pv_Message => Xv_Ret_Message);
      END IF;
    
    END LOOP;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Validate_Data;

  /*===============================================================
  Program Name:   Do_Insert_Process
  Author      :   SIE 谭家俊
  Created:    :   2018-07-01
  Purpose     :   数据写入接口表
  Parameters  :
              Pt_Iface_Tbl         IN Scux_Sie_Gl_Journal_Tbl --日记帐类信息
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
  Return  :
              Xn_Count             OUT NUMBER  --写入接口记录数
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 应收贷项发票取消核销API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-18    SIE 谭家俊         Creation    
    V1.2     2019-03-12    SIE张可盈       修改CREATED_BY与LAST_UPDATE_BY的传参
  ===============================================================*/
  PROCEDURE Do_Insert_Process(Pt_Iface_Tbl        IN Scux_Sie_Ar_Unapp_Cm_Tbl
                             ,Pn_Scux_Session_Id  IN NUMBER
                             ,Pv_Scux_Source_Code IN VARCHAR2
                             ,Xn_Count            OUT NUMBER
                             ,Xv_Ret_Status       OUT VARCHAR2
                             ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Insert_Process';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    Lt_Iface_Hrec Scux_Sie_Ar_Unapp_Cm_Iface%ROWTYPE;
    Ln_Count      NUMBER := 0;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    FOR i IN Pt_Iface_Tbl.First .. Pt_Iface_Tbl.Last LOOP
      Lt_Iface_Hrec := NULL;
    
      -----------------------------------------------  
      SELECT Scux_Sie_Ar_Unapp_Cm_Iface_s.Nextval
        INTO Lt_Iface_Hrec.Scux_Interface_Header_Id
        FROM Dual;
      Lt_Iface_Hrec.Scux_Session_Id := Pn_Scux_Session_Id;
    
      Lt_Iface_Hrec.Scux_Source_Code    := Scux_Sie_Interface_Pkg.Data_Format(Pv_Scux_Source_Code);
      Lt_Iface_Hrec.Scux_Source_Num     := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i).Scux_Source_Num);
      Lt_Iface_Hrec.Scux_Source_Id      := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i).Scux_Source_Id);
      Lt_Iface_Hrec.Scux_Process_Status := Gv_Pending;
    
      Lt_Iface_Hrec.Scux_Org_Name       := Pt_Iface_Tbl(i).Scux_Org_Name;
      Lt_Iface_Hrec.Scux_Org_Id         := Pt_Iface_Tbl(i).Scux_Org_Id;
      Lt_Iface_Hrec.Cm_Trx_Number       := Pt_Iface_Tbl(i).Cm_Trx_Number;
      Lt_Iface_Hrec.Cm_Customer_Trx_Id  := Pt_Iface_Tbl(i).Cm_Customer_Trx_Id;
      Lt_Iface_Hrec.Inv_Trx_Number      := Pt_Iface_Tbl(i).Inv_Trx_Number;
      Lt_Iface_Hrec.Inv_Customer_Trx_Id := Pt_Iface_Tbl(i).Inv_Customer_Trx_Id;
      -- Lt_Iface_Hrec.Reversal_Gl_Date    := Pt_Iface_Tbl(i).Reversal_Gl_Date;
    
      -----------------------------------------------  
      --日期字段转换
      Scux_Sie_Interface_Pkg.Date_Conversion(Pv_Date        => Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i).Reversal_Gl_Date)
                                            ,Pv_Date_Type   => Gv_Date_Type
                                            ,Xd_Date        => Lt_Iface_Hrec.Reversal_Gl_Date
                                            ,Xv_Ret_Status  => Xv_Ret_Status
                                            ,Xv_Ret_Message => Xv_Ret_Message);
    
      IF Xv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Fnd_Api.g_Ret_Sts_Unexp_Error
                                      ,Pv_Message => 'Reversal_Gl_Date' ||
                                                     Xv_Ret_Message);
      END IF;
    
      --end -----------------------------------------
      --V1.2    MOD   START---
      --  Lt_Iface_Hrec.Created_By       := Fnd_Global.User_Id;
      Lt_Iface_Hrec.Created_By    := Gn_User_Id;
      Lt_Iface_Hrec.Creation_Date := SYSDATE;
      --Lt_Iface_Hrec.Last_Updated_By  := Fnd_Global.User_Id;
      Lt_Iface_Hrec.Last_Updated_By := Gn_User_Id;
      --V1.2    MOD   END ---
      Lt_Iface_Hrec.Last_Update_Date := SYSDATE;
    
      INSERT INTO Scux_Sie_Ar_Unapp_Cm_Iface
      VALUES Lt_Iface_Hrec;
      Ln_Count := Ln_Count + 1;
    END LOOP;
  
    COMMIT;
  
    Xn_Count      := Ln_Count;
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Do_Insert_Process;

  /*===============================================================
  Program Name:   Do_Submit_Process
  Author      :   SIE 谭家俊
  Created:    :   2018-07-01
  Purpose     :   同步或异步调用应收贷项发票取消核销
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Synchro_Flag      IN VARCHAR2 --同步还是异步调用方式
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 同步或异步调用应收贷项发票取消核销 API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-18   SIE 谭家俊        Creation   
  V1.1      2018-12-17   SIE 郭剑          增加 Pv_Init_Flag 参数
  ===============================================================*/
  PROCEDURE Do_Submit_Process(Pn_Scux_Session_Id  IN NUMBER
                             ,Pv_Scux_Source_Code IN VARCHAR
                             ,Pv_Synchro_Flag     IN VARCHAR2
                             ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'N'
                             ,Xv_Ret_Status       OUT VARCHAR2
                             ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Submit_Process';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    --Ln_Count      NUMBER;
    Ln_Request_Id NUMBER;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    IF Pv_Synchro_Flag = 'Y' THEN
      Scux_Fnd_Log.Step(Lv_Api
                       ,'2.同步调用：-------------');
      Scux_Sie_Ar_Unapply_Cm_Imp_Pkg.Do_Import(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
                                              ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                                              ,Pv_Init_Flag        => Pv_Init_Flag --V1.1 'Y'
                                              ,Xv_Ret_Status       => Xv_Ret_Status
                                              ,Xv_Ret_Message      => Xv_Ret_Message);
      Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                        ,Pv_Ret_Message => Xv_Ret_Message);
    ELSE
    
      Scux_Fnd_Log.Step(Lv_Api
                       ,'3.异步调用：-------------');
      Ln_Request_Id := Fnd_Request.Submit_Request(Gv_Application_Code
                                                 ,'SCUX_SIE_AR_UNAPPLY_CM_IMP_PKG'
                                                 ,'SCUX.应收贷项发票取消核销'
                                                 ,To_Char(SYSDATE
                                                         ,'YYYY/MM/DD HH24:MI:SS')
                                                 ,FALSE
                                                 ,Pn_Scux_Session_Id
                                                 ,Pv_Scux_Source_Code
                                                 ,Pv_Init_Flag --V1.1 'N'
                                                 ,'N'
                                                 ,Chr(0));
    
      --  Log('lv_Request_Id=' || lv_Request_Id);
      IF Nvl(Ln_Request_Id
            ,0) = 0 THEN
      
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AR'
                                                       ,Pv_Message_Name     => 'AR_API_SYSP_CONC_SUBMIT_FAIL' --未能提交并发请求。                        
                                                        );
      
        Xv_Ret_Message := Lv_Api || Xv_Ret_Message;
      
        UPDATE Scux_Sie_Ar_Unapp_Cm_Iface
           SET Scux_Process_Status  = Gv_Error
              ,Scux_Process_Message = Xv_Ret_Message
              ,Scux_Process_Date    = SYSDATE
              ,Last_Update_Date     = SYSDATE
              ,Last_Updated_By      = Fnd_Global.User_Id
         WHERE Scux_Session_Id = Pn_Scux_Session_Id;
        RAISE Fnd_Api.g_Exc_Error;
      END IF;
    
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Do_Submit_Process;

  /*===============================================================
  Program Name:   Do_Import
  Author      :   SIE 谭家俊
  Created:    :   2018-07-01
  Purpose     :   应收贷项发票取消核销API
  Parameters  :
              Pt_Iface_Tbl         IN Scux_Sie_Gl_Journal_Tbl --日记帐类信息
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Synchro_Flag      IN VARCHAR2 --同步还是异步调用方式
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
              Pv_Language          IN VARCHAR2 --语言
  Return  :
              Xn_Scux_Session_Id   OUT NUMBER  --批次ID
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 应收贷项发票取消核销API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-18    SIE 谭家俊         Creation    
  V1. 2       2019-03-12    SIE张可盈     V1.        2019-03-12    SIE张可盈      Do_Import方法添加Pv_Created_by参数与Scux_Sie_Interface_Pkg.Get_Created_By(Pv_Created_By);
  ===============================================================*/
  PROCEDURE Do_Import(Pt_Iface_Tbl        IN Scux_Sie_Ar_Unapp_Cm_Tbl
                     ,Pv_Scux_Source_Code IN VARCHAR2
                     ,Pv_Synchro_Flag     IN VARCHAR2 DEFAULT 'Y' -- 是否同步调用
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'N' --V1.1 'Y' --是否初始化环境
                     ,Pv_Language         IN VARCHAR2 DEFAULT 'ZHS'
                     ,Xn_Scux_Session_Id  OUT NUMBER
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2
                     ,Pv_Created_By       IN VARCHAR2 DEFAULT NULL --V1.2 MOD
                      
                      ) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Import';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    --Lv_Step VARCHAR2(240);
  
    Ln_Count NUMBER := 0;
    --Lv_Request_Id NUMBER;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    Scux_Sie_Interface_Pkg.Set_Language(Pv_Language);
  
    Xn_Scux_Session_Id := Scux_Sie_Interface_Pkg.Get_Session_Id;
    --V1.2    ADD  START --
    Gn_User_Id := Scux_Sie_Interface_Pkg.Get_Created_By(Pv_Created_By);
    --V1.2     ADD    END ---
    Scux_Fnd_Log.Step(Lv_Api
                     ,'1.Check_Parameter：-------------');
    Validate_Data(Pt_Iface_Tbl        => Pt_Iface_Tbl
                 ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                 ,Xv_Ret_Status       => Xv_Ret_Status
                 ,Xv_Ret_Message      => Xv_Ret_Message);
    Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                      ,Pv_Ret_Message => Xv_Ret_Message);
  
    Scux_Fnd_Log.Step(Lv_Api
                     ,'2.Insert Data：-------------');
    Do_Insert_Process(Pt_Iface_Tbl        => Pt_Iface_Tbl
                     ,Pn_Scux_Session_Id  => Xn_Scux_Session_Id
                     ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                     ,Xn_Count            => Ln_Count
                     ,Xv_Ret_Status       => Xv_Ret_Status
                     ,Xv_Ret_Message      => Xv_Ret_Message);
    Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                      ,Pv_Ret_Message => Xv_Ret_Message);
    ---------------------------------------------------------------------
  
    IF Ln_Count > 0 THEN
      --同步或异步调用导入接口
      Scux_Fnd_Log.Step(Lv_Api
                       ,'3.Submit_Process：-------------');
      Do_Submit_Process(Pn_Scux_Session_Id  => Xn_Scux_Session_Id
                       ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                       ,Pv_Synchro_Flag     => Pv_Synchro_Flag
                       ,Pv_Init_Flag        => Pv_Init_Flag --V1.1 ADD
                       ,Xv_Ret_Status       => Xv_Ret_Status
                       ,Xv_Ret_Message      => Xv_Ret_Message);
      Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                        ,Pv_Ret_Message => Xv_Ret_Message);
    ELSE
      --xv_Ret_Status := '没有需要提交的数据';
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'SQLGL'
                                                     ,Pv_Message_Name     => 'GL_COA_SVI_DATA_NOT_PASSED' --API 没有找到要处理的数据。
                                                      );
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
    
  END Do_Import;

END Scux_Sie_Ar_Unapply_Cm_Api_Pkg;
/
