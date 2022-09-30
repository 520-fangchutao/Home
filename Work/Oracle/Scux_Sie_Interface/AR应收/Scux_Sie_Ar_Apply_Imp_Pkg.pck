CREATE OR REPLACE PACKAGE Scux_Sie_Ar_Apply_Imp_Pkg IS

  /*=============================================================
  Copyright (C)  SIE Consulting Co., Ltd    
  All rights reserved 
  ===============================================================
  Program Name:   Scux_Sie_Gl_Journals_Imp_Pkg
  Author      :   SIE 高朋
  Created:    :   2018-10-05
  Purpose     :   
  Description : 标准准化收款核销发票导入主程序（版本管控）
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0     2018-10-05    SIE 高朋        Creation
  V1.1     S018-12-26    SIE 郭剑        验证补充
  ===============================================================*/
  /*===============================================================
  Program Name:   Do_Import
  Author      :   SIE 高朋
  Created:    :   2018-10-05
  Purpose     :   标准准化收款核销发票主程序入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 标准准化收款核销发票主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-05    SIE 高朋         Creation  
  ===============================================================*/
  PROCEDURE Do_Import(Pn_Scux_Session_Id  IN NUMBER
                     ,Pv_Scux_Source_Code IN VARCHAR
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'Y' --是否初始化环境
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2);

  /*===============================================================
  Program Name:   Main
  Author      :   SIE 高朋
  Created:    :   2018-10-05
  Purpose     :   AR收款核销发票导入并发调用入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
  Return  :
              Errbuf               OUT VARCHAR2--状态
              Retcode              OUT VARCHAR2--错误信息
  Description: AR收款核销发票导入主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-05    SIE 高朋         Creation    
  V1.1      2018-12-17    SIE 郭剑         标准化修改  
  ===============================================================*/
  PROCEDURE Main(Errbuf              OUT VARCHAR2
                ,Retcode             OUT VARCHAR2
                ,Pn_Scux_Session_Id  IN NUMBER
                ,Pv_Scux_Source_Code IN VARCHAR
                ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'N' --是否初始化环境
                 );

END Scux_Sie_Ar_Apply_Imp_Pkg;
/
CREATE OR REPLACE PACKAGE BODY Scux_Sie_Ar_Apply_Imp_Pkg IS

  Gv_Package_Name CONSTANT VARCHAR2(30) := 'Scux_Sie_Ar_Apply_Imp_Pkg';

  Gv_Pending   CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Pending; -- 'PENDING'; --待定
  Gv_Running   CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Running; -- 'RUNNING'; --运行中
  Gv_Submit    CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Submit; -- 'SUBMIT'; --已提交(用于异步调用并发请求中间状态
  Gv_Completed CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Completed; -- 'COMPLETED'; --已完成
  Gv_Error     CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Error; -- 'ERROR'; --错误

  Gn_User_Id         NUMBER := Fnd_Global.User_Id;
  Gn_Main_Request_Id NUMBER; --主程序并发请求ID
  Gv_Step_Je_Create CONSTANT VARCHAR2(30) := '1.Journal_Create';
  Gv_Step_Je_Post   CONSTANT VARCHAR2(30) := '2.Journal_Post';

  Gn_Request_Id NUMBER := Fnd_Global.Conc_Request_Id;

  Gv_Application_Code CONSTANT VARCHAR2(30) := Scux_Fnd_Log.Gv_Application_Code;

  /*===============================================================
  Program Name:   Validate_Org
  Author      :   SIE 高朋
  Created:    :   2018-10-10
  Purpose     :   验证业务实体
  Parameters  :            Pn_Org_Id          IN NUMBER --业务实体ID
                          ,Pv_Scux_Org_Name    IN VARCHAR2  --业务实体
  
  Return  :                Xv_Ret_Status  OUT VARCHAR2 --状态
                           Xv_Ret_Message OUT VARCHAR2 --错误信息
  Description:
  
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-10    SIE 高朋         Creation
  ===============================================================*/

  PROCEDURE Validate_Org(Pn_Org_Id        IN NUMBER
                        ,Pv_Scux_Org_Name IN VARCHAR2
                        ,Xn_Org_Id        OUT NUMBER
                        ,Xv_Ret_Status    OUT VARCHAR2
                        ,Xv_Ret_Message   OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Org_Id';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    IF Pn_Org_Id IS NULL
       AND Pv_Scux_Org_Name IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'ORG_ID/SCUX_ORG_NAME');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    
    END IF;
  
    BEGIN
      SELECT Hou.Organization_Id
        INTO Xn_Org_Id
        FROM Hr_Operating_Units Hou
       WHERE (Hou.Organization_Id = Pn_Org_Id OR Pn_Org_Id IS NULL)
         AND (Hou.Name = Pv_Scux_Org_Name OR Pv_Scux_Org_Name IS NULL);
    
    EXCEPTION
      WHEN OTHERS THEN
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AHL'
                                                       ,Pv_Message_Name     => 'AHL_OSP_ORD_INV_OPUNIT' --业务实体无效
                                                        );
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Xv_Ret_Status
                                      ,Pv_Message => Xv_Ret_Message);
    END;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api => Lv_Api
                                                --,Pv_Error_Code  => Lv_Error_Code
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Validate_Cash_Receipt
  Author      :   SIE  高朋
  Created:    :   2018-10-10
  Purpose     :   验证收款单
  Parameters  :            Pn_Org_Id          IN NUMBER --业务实体ID
                          ,Pv_Receipt_Number    IN VARCHAR2  --收款单号
                          ,Pn_Cash_Receipt_Id    IN VARCHAR2  --收款单号ID
  
  Return  :                
                           Xn_Cash_Receipt_Id OUT NUMBER
                           Xn_Pay_Customer_Id OUT NUMBER --V1.1 ADD
                           Xv_Ret_Status  OUT VARCHAR2 --状态
                           Xv_Ret_Message OUT VARCHAR2 --错误信息
  Description:
  
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-10    SIE  高朋         Creation
  V1.1      2018-12-16    SIE  郭剑         加入日期不能为空判断，优化
  ===============================================================*/
  PROCEDURE Validate_Cash_Receipt(Pn_Org_Id          IN NUMBER
                                 ,Pv_Receipt_Number  IN VARCHAR2
                                 ,Pn_Cash_Receipt_Id IN NUMBER
                                 ,Pn_Applied_Amount  IN NUMBER
                                 ,Xn_Cash_Receipt_Id OUT NUMBER
                                 ,Xn_Pay_Customer_Id OUT NUMBER --V1.1 ADD
                                 ,Xv_Ret_Status      OUT VARCHAR2
                                 ,Xv_Ret_Message     OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Cash_Receipt_Id';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Ln_Applied_Amount NUMBER;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pv_Receipt_Number IS NULL
       AND Pn_Cash_Receipt_Id IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'CASH_RECEIPT_ID/RECEIPT_NUMBER');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    
    END IF;
  
    --V1.1 ADD START --
    IF Pn_Applied_Amount IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Applied_Amount');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
    --V1.1 ADD END --
  
    IF Pn_Org_Id IS NOT NULL THEN
      BEGIN
        --V1.1 MOD START--
        --优化
        /*SELECT Cash.Cash_Receipt_Id
         INTO Xn_Cash_Receipt_Id
         FROM Ar_Cash_Receipts_All Cash
        WHERE Cash.Org_Id = Pn_Org_Id
          AND (Cash.Receipt_Number = Pv_Receipt_Number OR
              Pv_Receipt_Number IS NULL)
          AND (Cash.Cash_Receipt_Id = Pn_Cash_Receipt_Id OR
              Pn_Cash_Receipt_Id IS NULL);*/
        IF Pn_Cash_Receipt_Id IS NOT NULL THEN
          SELECT Cash.Cash_Receipt_Id
                ,Cash.Amount
                ,Cash.Pay_From_Customer
            INTO Xn_Cash_Receipt_Id
                ,Ln_Applied_Amount
                ,Xn_Pay_Customer_Id
            FROM Ar_Cash_Receipts_All Cash
           WHERE Cash.Org_Id = Pn_Org_Id
             AND Cash.Cash_Receipt_Id = Pn_Cash_Receipt_Id;
        ELSIF Pv_Receipt_Number IS NOT NULL THEN
          SELECT Cash.Cash_Receipt_Id
                ,Cash.Amount
                ,Cash.Pay_From_Customer
            INTO Xn_Cash_Receipt_Id
                ,Ln_Applied_Amount
                ,Xn_Pay_Customer_Id
            FROM Ar_Cash_Receipts_All Cash
           WHERE Cash.Org_Id = Pn_Org_Id
             AND Cash.Receipt_Number = Pv_Receipt_Number;
        END IF;
        --V1.1 MOD END--   
      EXCEPTION
        WHEN OTHERS THEN
          Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
          Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                         ,Pv_Message_Name     => 'SCUX_SIE_AR_UNAPP_IMP_MS_001');
        
          Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                        ,Pv_Status  => Xv_Ret_Status
                                        ,Pv_Message => Xv_Ret_Message);
      END;
    END IF;
  
    --V1.1 MOD START--
    --IF Xn_Cash_Receipt_Id IS NOT NULL THEN
  
    /*SELECT Cash.Amount
     INTO Ln_Applied_Amount
     FROM Ar_Cash_Receipts_All Cash
    WHERE Cash.Cash_Receipt_Id = Xn_Cash_Receipt_Id;*/
    --V1.1 MOD END--   
  
    IF Ln_Applied_Amount >= Pn_Applied_Amount THEN
      Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
      Scux_Fnd_Log.Event(Lv_Api
                        ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
    ELSE
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_AR_RECEIPT_APPLY_MS_001');
    
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
  
    -- END IF; --V1.1 MOD 
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api         => Lv_Api
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Validate_Customer_Trx
  Author      :   SIE  高朋
  Created:    :   2018-10-10
  Purpose     :   验证应收发票
  Parameters  :            Pn_Org_Id          IN NUMBER --业务实体ID
                          ,Pv_Trx_Number    IN VARCHAR2  --应收发票号
                          ,Pn_Customer_Trx_Id    IN VARCHAR2  --应收发票号ID
  
  Return  :                Xn_Customer_Trx_Id OUT --应收发票号ID
                           Xn_Trx_Customer_Id OUT NUMBER --应收发票客户V1.1 ADD  
                           Xv_Ret_Status  OUT VARCHAR2 --状态
                           Xv_Ret_Message OUT VARCHAR2 --错误信息
  Description:
  
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-10    SIE  高朋         Creation
  V1.1      2018-12-16    SIE  郭剑         优化
  ===============================================================*/

  PROCEDURE Validate_Customer_Trx(Pn_Org_Id          IN NUMBER
                                 ,Pv_Trx_Number      IN VARCHAR2
                                 ,Pn_Customer_Trx_Id IN NUMBER
                                 ,Xn_Customer_Trx_Id OUT NUMBER
                                 ,Xn_Trx_Customer_Id OUT NUMBER --V1.1 ADD
                                 ,Xv_Ret_Status      OUT VARCHAR2
                                 ,Xv_Ret_Message     OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Customer_Trx_Id';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pv_Trx_Number IS NULL
       AND Pn_Customer_Trx_Id IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'CUSTOMER_TRX_ID/TRX_NUMBER');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    
    END IF;
  
    IF Pn_Org_Id IS NOT NULL THEN
      BEGIN
        --V1.1 MOD START --
        --优化
        /*SELECT Rcta.Customer_Trx_Id
         INTO Xn_Customer_Trx_Id
         FROM Ra_Customer_Trx_All Rcta
        WHERE Rcta.Org_Id = Pn_Org_Id
          AND (Rcta.Trx_Number = Pv_Trx_Number OR Pv_Trx_Number IS NULL)
          AND (Rcta.Customer_Trx_Id = Pn_Customer_Trx_Id OR
              Pn_Customer_Trx_Id IS NULL);*/
        IF Pn_Customer_Trx_Id IS NOT NULL THEN
          SELECT Rcta.Customer_Trx_Id
                ,Rcta.Bill_To_Customer_Id
            INTO Xn_Customer_Trx_Id
                ,Xn_Trx_Customer_Id
            FROM Ra_Customer_Trx_All Rcta
           WHERE Rcta.Org_Id = Pn_Org_Id
             AND Rcta.Customer_Trx_Id = Pn_Customer_Trx_Id;
        ELSIF Pv_Trx_Number IS NOT NULL THEN
          SELECT Rcta.Customer_Trx_Id
                ,Rcta.Bill_To_Customer_Id
            INTO Xn_Customer_Trx_Id
                ,Xn_Trx_Customer_Id
            FROM Ra_Customer_Trx_All Rcta
           WHERE Rcta.Org_Id = Pn_Org_Id
             AND Rcta.Trx_Number = Pv_Trx_Number;
        END IF;
        --V1.1 MOD START --
      EXCEPTION
        WHEN OTHERS THEN
          Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
          Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                         ,Pv_Message_Name     => 'SCUX_SIE_AR_UNAPP_IMP_MS_002');
        
          Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                        ,Pv_Status  => Xv_Ret_Status
                                        ,Pv_Message => Xv_Ret_Message);
      END;
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api => Lv_Api
                                                --,Pv_Error_Code  => Lv_Error_Code
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Validate_Applied_Date
  Author      :   SIE  郭剑
  Created:    :   2018-12-16
  Purpose     :   验证日期
  Parameters  :            Pd_Applied_Date    IN DATE  --验证日期
  
  Return  :               Xv_Ret_Status  OUT VARCHAR2 --状态
                           Xv_Ret_Message OUT VARCHAR2 --错误信息
  Description:
  
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.1      2018-12-16   SIE  郭剑         Creation
  ===============================================================*/
  PROCEDURE Validate_Applied_Date(Pd_Applied_Date IN DATE
                                 ,Xv_Ret_Status   OUT VARCHAR2
                                 ,Xv_Ret_Message  OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Applied_Date';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Ln_Cnt            NUMBER;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pd_Applied_Date IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Applied_Date');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api         => Lv_Api
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Validate_Gl_Date
  Author      :   SIE  高朋
  Created:    :   2018-10-10
  Purpose     :   验证冲销总账日期
  Parameters  :            Pn_Org_Id          IN NUMBER --业务实体ID
                          ,Pd_Gl_Date    IN DATE  --总账日期
  
  Return  :               Xv_Ret_Status  OUT VARCHAR2 --状态
                           Xv_Ret_Message OUT VARCHAR2 --错误信息
  Description:
  
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-10    SIE  高朋         Creation
  V1.1      2018-12-16    SIE  郭剑         日期必须不为空
  ===============================================================*/
  PROCEDURE Validate_Gl_Date(Pn_Org_Id      IN NUMBER
                            ,Pd_Gl_Date     IN DATE
                            ,Xv_Ret_Status  OUT VARCHAR2
                            ,Xv_Ret_Message OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Gl_Date';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Ln_Cnt            NUMBER;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    --V1.1 MOD START --
    IF Pd_Gl_Date IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Gl_Date');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
    --V1.1 MOD END --
  
    IF Pn_Org_Id IS NOT NULL
       AND Pd_Gl_Date IS NOT NULL THEN
      BEGIN
      
        SELECT COUNT(1)
          INTO Ln_Cnt
          FROM Gl_Period_Statuses Gps
         WHERE Gps.Set_Of_Books_Id IN
               (SELECT Hou.Set_Of_Books_Id
                  FROM Hr_Operating_Units Hou
                 WHERE Hou.Organization_Id = Pn_Org_Id)
           AND Gps.Application_Id = 101
           AND Gps.Closing_Status = 'O'
           AND Gps.Start_Date <= Trunc(Pd_Gl_Date)
           AND Gps.End_Date >= Trunc(Pd_Gl_Date)
           AND Gps.Adjustment_Period_Flag = 'N';
      
        IF Ln_Cnt = 0 THEN
          Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
          Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AMS'
                                                         ,Pv_Message_Name     => 'AMS_SETL_GLDATE_INVALID' --GL 日期无效。GL 日期不在打开期间内。
                                                          );
        
          Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                        ,Pv_Status  => Xv_Ret_Status
                                        ,Pv_Message => Xv_Ret_Message);
        END IF;
      END;
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api         => Lv_Api
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Validate_Customer
  Author      :   SIE  高朋
  Created:    :   2018-10-10
  Purpose     :   验证收款 和发票的 客户是否一致
  Parameters  :            Pn_Pay_Customer_Id         IN NUMBER --付款ID
                          ,Pn_Trx_Customer_Id         IN NUMBER  --发票ID
  
  Return  :               Xv_Ret_Status  OUT VARCHAR2 --状态
                           Xv_Ret_Message OUT VARCHAR2 --错误信息
  Description:
  
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.1      2018-12-16    SIE  郭剑       从API内移入
  ===============================================================*/
  PROCEDURE Validate_Customer(Pn_Pay_Customer_Id IN NUMBER
                             ,Pn_Trx_Customer_Id IN NUMBER
                             ,Xv_Ret_Status      OUT VARCHAR2
                             ,Xv_Ret_Message     OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Customer';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pn_Pay_Customer_Id IS NOT NULL
       AND Pn_Trx_Customer_Id IS NOT NULL THEN
      IF Pn_Pay_Customer_Id <> Pn_Trx_Customer_Id THEN
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                       ,Pv_Message_Name     => 'SCUX_AR_RECEIPT_APPLY_MS_002');
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Xv_Ret_Status
                                      ,Pv_Message => Xv_Ret_Message);
      END IF;
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api         => Lv_Api
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Validate_Data
  Author      :   SIE 高朋
  Created:    :   2018-10-10
  Purpose     :   验证数据入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description:
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-10    SIE 高朋         Creation
  V1.1      2018-12-17    SIE 郭剑         添加验证
  ===============================================================*/
  PROCEDURE Validate_Data(Pn_Scux_Session_Id  IN NUMBER
                         ,Pv_Scux_Source_Code IN VARCHAR
                         ,Xv_Ret_Status       OUT VARCHAR2
                         ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Data';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    --接口信息
    CURSOR Crs_Scux_Apply IS
      SELECT h.*
        FROM Scux_Sie_Ar_Apply_Iface h
       WHERE h.Scux_Session_Id = Pn_Scux_Session_Id
         AND h.Scux_Source_Code = Pv_Scux_Source_Code
         AND h.Scux_Process_Status = Gv_Pending;
  
    Lv_Ret_Status  VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    Lv_Ret_Message VARCHAR2(2000);
  
    Lt_Apply_Rec       Scux_Sie_Ar_Apply_Iface%ROWTYPE;
    Ln_Pay_Customer_Id NUMBER; --V1.1 ADD
    Ln_Trx_Customer_Id NUMBER; --V1.1 ADD
  
    Lv_Step VARCHAR2(1000);
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    FOR Rec_Apply IN Crs_Scux_Apply LOOP
      BEGIN
        Lv_Step := '1.Validate_date:';
      
        Lt_Apply_Rec                      := NULL;
        Lt_Apply_Rec.Scux_Process_Status  := Fnd_Api.g_Ret_Sts_Success;
        Lt_Apply_Rec.Scux_Process_Message := NULL;
        Lv_Ret_Status                     := Fnd_Api.g_Ret_Sts_Success;
        Lv_Ret_Message                    := NULL;
      
        --验证组织
        Validate_Org(Pn_Org_Id        => Rec_Apply.Org_Id
                    ,Pv_Scux_Org_Name => Rec_Apply.Scux_Org_Name
                    ,Xn_Org_Id        => Lt_Apply_Rec.Org_Id
                    ,Xv_Ret_Status    => Lv_Ret_Status
                    ,Xv_Ret_Message   => Lv_Ret_Message);
      
        IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
          Lt_Apply_Rec.Scux_Process_Status  := Lv_Ret_Status;
          Lt_Apply_Rec.Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Apply_Rec.Scux_Process_Message
                                                                                     ,Lv_Ret_Message);
        END IF;
      
        --验证收款单
        Validate_Cash_Receipt(Pn_Org_Id          => Lt_Apply_Rec.Org_Id
                             ,Pv_Receipt_Number  => Rec_Apply.Receipt_Number
                             ,Pn_Cash_Receipt_Id => Rec_Apply.Receipt_Id
                             ,Pn_Applied_Amount  => Rec_Apply.Applied_Amount
                             ,Xn_Cash_Receipt_Id => Lt_Apply_Rec.Receipt_Id
                             ,Xn_Pay_Customer_Id => Ln_Pay_Customer_Id
                             ,Xv_Ret_Status      => Lv_Ret_Status
                             ,Xv_Ret_Message     => Lv_Ret_Message);
      
        IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
          Lt_Apply_Rec.Scux_Process_Status  := Lv_Ret_Status;
          Lt_Apply_Rec.Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Apply_Rec.Scux_Process_Message
                                                                                     ,Lv_Ret_Message);
        END IF;
      
        --验证应收发票
        Validate_Customer_Trx(Pn_Org_Id          => Lt_Apply_Rec.Org_Id
                             ,Pv_Trx_Number      => Rec_Apply.Trx_Number
                             ,Pn_Customer_Trx_Id => Rec_Apply.Customer_Trx_Id
                             ,Xn_Customer_Trx_Id => Lt_Apply_Rec.Customer_Trx_Id
                             ,Xn_Trx_Customer_Id => Ln_Trx_Customer_Id --V1.1 ADD
                             ,Xv_Ret_Status      => Lv_Ret_Status
                             ,Xv_Ret_Message     => Lv_Ret_Message);
        IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
          Lt_Apply_Rec.Scux_Process_Status  := Lv_Ret_Status;
          Lt_Apply_Rec.Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Apply_Rec.Scux_Process_Message
                                                                                     ,Lv_Ret_Message);
        END IF;
      
        --验证总账日期
        Validate_Gl_Date(Pn_Org_Id      => Lt_Apply_Rec.Org_Id
                        ,Pd_Gl_Date     => Rec_Apply.Applied_Gl_Date
                        ,Xv_Ret_Status  => Lv_Ret_Status
                        ,Xv_Ret_Message => Lv_Ret_Message);
      
        IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
          Lt_Apply_Rec.Scux_Process_Status  := Lv_Ret_Status;
          Lt_Apply_Rec.Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Apply_Rec.Scux_Process_Message
                                                                                     ,Lv_Ret_Message);
        END IF;
      
        --验证日期
        Validate_Applied_Date(Pd_Applied_Date => Rec_Apply.Applied_Date
                             ,Xv_Ret_Status   => Lv_Ret_Status
                             ,Xv_Ret_Message  => Lv_Ret_Message);
      
        IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
          Lt_Apply_Rec.Scux_Process_Status  := Lv_Ret_Status;
          Lt_Apply_Rec.Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Apply_Rec.Scux_Process_Message
                                                                                     ,Lv_Ret_Message);
        END IF;
      
        --V1.1 MOD START --
        Validate_Customer(Pn_Pay_Customer_Id => Ln_Pay_Customer_Id
                         ,Pn_Trx_Customer_Id => Ln_Trx_Customer_Id
                         ,Xv_Ret_Status      => Lv_Ret_Status
                         ,Xv_Ret_Message     => Lv_Ret_Message);
      
        IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
          Lt_Apply_Rec.Scux_Process_Status  := Lv_Ret_Status;
          Lt_Apply_Rec.Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Apply_Rec.Scux_Process_Message
                                                                                     ,Lv_Ret_Message);
        END IF;
        --V1.1 MOD END --
      
        --验证是否存在核销关系
        /* Validate_Apply_Relation(Pn_Cash_Receipt_Id => Lt_apply_Rec.Cash_Receipt_Id
                               ,Pn_Customer_Trx_Id => Lt_apply_Rec.Customer_Trx_Id
                               ,Xv_Ret_Status      => Lv_Ret_Status
                               ,Xv_Ret_Message     => Lv_Ret_Message);
        
        IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
          Lt_apply_Rec.Scux_Process_Status  := Lv_Ret_Status;
          Lt_apply_Rec.Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_apply_Rec.Scux_Process_Message
                                                                                      ,Lv_Ret_Message);
        END IF;*/
      
        --判断是否有异常      
        IF Lt_Apply_Rec.Scux_Process_Status = Fnd_Api.g_Ret_Sts_Success THEN
        
          UPDATE Scux_Sie_Ar_Apply_Iface h
             SET h.Scux_Process_Step    = Lv_Procedure_Name
                ,h.Scux_Process_Status  = Gv_Running
                ,h.Scux_Process_Date    = SYSDATE
                ,h.Scux_Process_Message = NULL
                 --------------------------------------------------------
                ,h.Last_Updated_By  = Nvl(h.Last_Updated_By
                                         ,Gn_User_Id)
                ,h.Last_Update_Date = SYSDATE
                 --,H.Program_Application_Id = Fnd_Global.Prog_Appl_Id
                 --,H.Program_Id = Fnd_Global.Conc_Program_Id
                 --,H.Program_Update_Date = SYSDATE
                 --,H.Request_Id = Gn_Request_Id
                 --------------------------------------------------------
                ,h.Receipt_Id      = Lt_Apply_Rec.Receipt_Id
                ,h.Customer_Trx_Id = Lt_Apply_Rec.Customer_Trx_Id
                ,h.Org_Id          = Lt_Apply_Rec.Org_Id
           WHERE h.Scux_Interface_Header_Id =
                 Rec_Apply.Scux_Interface_Header_Id;
        
        ELSE
          --验证失败
        
          UPDATE Scux_Sie_Ar_Apply_Iface h
             SET h.Scux_Process_Step    = Lv_Procedure_Name
                ,h.Scux_Process_Status  = Gv_Error
                ,h.Scux_Process_Date    = SYSDATE
                ,h.Scux_Process_Message = Lt_Apply_Rec.Scux_Process_Message
                 --------------------------------------------------------
                ,h.Last_Updated_By  = Nvl(h.Last_Updated_By
                                         ,Gn_User_Id)
                ,h.Last_Update_Date = SYSDATE
          --,H.Program_Application_Id = Fnd_Global.Prog_Appl_Id
          --,H.Program_Id = Fnd_Global.Conc_Program_Id
          --,H.Program_Update_Date = SYSDATE
          --,H.Request_Id = Gn_Request_Id
          --------------------------------------------------------
          
           WHERE h.Scux_Interface_Header_Id =
                 Rec_Apply.Scux_Interface_Header_Id;
        
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          Lv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
          Lv_Ret_Message := Lv_Step || SQLCODE || '--' || SQLERRM;
        
          --回写接口
        
          UPDATE Scux_Sie_Ar_Apply_Iface h
             SET h.Scux_Process_Step    = Lv_Procedure_Name
                ,h.Scux_Process_Status  = Gv_Error
                ,h.Scux_Process_Date    = SYSDATE
                ,h.Scux_Process_Message = Substrb(Lv_Ret_Message
                                                 ,1
                                                 ,240)
                 --------------------------------------------------------
                ,h.Last_Updated_By        = Nvl(h.Last_Updated_By
                                               ,Gn_User_Id)
                ,h.Last_Update_Date       = SYSDATE
                ,h.Program_Application_Id = Fnd_Global.Prog_Appl_Id
                ,h.Program_Id             = Fnd_Global.Conc_Program_Id
                ,h.Program_Update_Date    = SYSDATE
                ,h.Request_Id             = Gn_Request_Id
          --------------------------------------------------------
           WHERE h.Scux_Interface_Header_Id =
                 Rec_Apply.Scux_Interface_Header_Id;
        
      END;
    
      COMMIT;
    END LOOP;
  
    COMMIT;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Do_Set_Error
  Author      :   SIE  高朋
  Created:    :   2018-08-24
  Purpose     :   将错误信息推送到错误公用记录表
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
  
  Description: 将错误信息推送到错误公用记录表 Scux_Sie_Interface_Errors
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0     2018-08-24    SIE  高朋        Creation
  ===============================================================*/
  PROCEDURE Do_Set_Error(Pn_Scux_Session_Id  IN NUMBER
                        ,Pv_Scux_Source_Code IN VARCHAR2
                        ,Xv_Ret_Status       IN OUT VARCHAR2
                        ,Xv_Ret_Message      IN OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Set_Error';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    CURSOR Crs_Scux_Std_Header IS
      SELECT Crs.Scux_Interface_Header_Id
            ,Crs.Scux_Session_Id
            ,Crs.Scux_Source_Code
            ,Crs.Scux_Source_Num
            ,Crs.Scux_Source_Id
            ,Crs.Scux_Process_Group_Id
            ,Crs.Scux_Process_Step
            ,Crs.Scux_Process_Status
            ,Crs.Scux_Process_Date
            ,Crs.Scux_Process_Message
        FROM Scux_Sie_Ar_Apply_Iface Crs
       WHERE Crs.Scux_Process_Status = Gv_Error
         AND Crs.Scux_Source_Code = Pv_Scux_Source_Code
         AND Crs.Scux_Session_Id = Pn_Scux_Session_Id;
  
    Lr_Scux_Std_Column Scux_Sie_Interface_Pkg.Gr_Scux_Std_Column;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Xv_Ret_Status = Fnd_Api.g_Ret_Sts_Success THEN
    
      FOR Rec_Header IN Crs_Scux_Std_Header LOOP
        Lr_Scux_Std_Column := NULL;
      
        Lr_Scux_Std_Column.Scux_Interface_Header_Id := Rec_Header.Scux_Interface_Header_Id;
        Lr_Scux_Std_Column.Scux_Session_Id          := Rec_Header.Scux_Session_Id;
        Lr_Scux_Std_Column.Scux_Source_Code         := Rec_Header.Scux_Source_Code;
        Lr_Scux_Std_Column.Scux_Source_Num          := Rec_Header.Scux_Source_Num;
        Lr_Scux_Std_Column.Scux_Source_Id           := Rec_Header.Scux_Source_Id;
        Lr_Scux_Std_Column.Scux_Process_Group_Id    := Rec_Header.Scux_Process_Group_Id;
        Lr_Scux_Std_Column.Scux_Process_Step        := Rec_Header.Scux_Process_Step;
        Lr_Scux_Std_Column.Scux_Process_Status      := Rec_Header.Scux_Process_Status;
        Lr_Scux_Std_Column.Scux_Process_Date        := Rec_Header.Scux_Process_Date;
        Lr_Scux_Std_Column.Scux_Process_Message     := Rec_Header.Scux_Process_Message;
      
        Scux_Sie_Interface_Pkg.Set_Error(Pv_Source_Code     => Gv_Package_Name
                                        ,Pv_Table_Name      => 'Scux_Sie_Ar_Apply_Iface'
                                        ,Pr_Scux_Std_Column => Lr_Scux_Std_Column);
      
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Substr(Xv_Ret_Message || ' ' ||
                                 Lr_Scux_Std_Column.Scux_Process_Message
                                ,1
                                ,240);
      
      END LOOP;
    
    END IF;
  
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Do_Set_Error;

  /*===============================================================
  Program Name:   Do_apply
  Author      :   SIE  高朋
  Created:    :   2018-10-10
  Purpose     :   提交核销
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pn_Main_Request_Id   IN NUMBER   --调用的父并发请求
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description:
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0     2018-10-10   SIE  高朋        Creation
  V1.1     2018-12-17   SIE  郭剑        错语信息修订
  ===============================================================*/
  PROCEDURE Do_Apply(Pn_Scux_Session_Id  IN NUMBER
                    ,Pv_Scux_Source_Code IN VARCHAR
                    ,Xv_Ret_Status       OUT VARCHAR2
                    ,Xv_Ret_Message      OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Apply';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    --接口信息
    CURSOR Crs_Scux_Apply IS
      SELECT h.*
        FROM Scux_Sie_Ar_Apply_Iface h
       WHERE h.Scux_Session_Id = Pn_Scux_Session_Id
         AND h.Scux_Source_Code = Pv_Scux_Source_Code
         AND h.Scux_Process_Status = Gv_Running
       ORDER BY h.Scux_Interface_Header_Id;
  
    Lv_Ret_Status VARCHAR2(30);
    Ln_Msg_Count  NUMBER;
    Lv_Msg_Data   VARCHAR2(2000);
  
    Ln_Msg_Index_Out        NUMBER;
    Lv_Scux_Process_Message Scux_Sie_Ar_Apply_Iface.Scux_Process_Message%TYPE;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    --
    FOR Rec_Apply IN Crs_Scux_Apply LOOP
    
      Lv_Scux_Process_Message := NULL;
    
      --初始化组织
      Mo_Global.Init('AR');
      Mo_Global.Set_Policy_Context('S'
                                  ,Rec_Apply.Org_Id);
    
      --调用API
      IF Rec_Apply.Currency_Conversion_Rate = 1 THEN
        Ar_Receipt_Api_Pub.Apply(p_Api_Version                 => 1.0
                                ,p_Init_Msg_List               => NULL
                                ,p_Commit                      => NULL
                                ,p_Validation_Level            => NULL
                                ,x_Return_Status               => Lv_Ret_Status
                                ,x_Msg_Count                   => Ln_Msg_Count
                                ,x_Msg_Data                    => Lv_Msg_Data
                                ,p_Cash_Receipt_Id             => Rec_Apply.Receipt_Id
                                ,p_Receipt_Number              => NULL --Rec_Apply.Receipt_Number
                                ,p_Customer_Trx_Id             => Rec_Apply.Customer_Trx_Id
                                ,p_Trx_Number                  => NULL --Rec_Apply.Trx_Number
                                ,p_Installment                 => NULL
                                ,p_Applied_Payment_Schedule_Id => Rec_Apply.Payment_Schedule_Id
                                ,p_Amount_Applied              => Rec_Apply.Applied_Amount
                                ,p_Amount_Applied_From         => NULL
                                ,p_Trans_To_Receipt_Rate       => NULL --Rec_Apply.Currency_Conversion_Rate
                                ,p_Discount                    => NULL
                                ,p_Apply_Date                  => Rec_Apply.Applied_Date
                                ,p_Apply_Gl_Date               => Rec_Apply.Applied_Gl_Date
                                ,p_Ussgl_Transaction_Code      => NULL
                                ,p_Customer_Trx_Line_Id        => NULL
                                ,p_Line_Number                 => NULL
                                ,p_Show_Closed_Invoices        => NULL
                                ,p_Called_From                 => NULL
                                ,p_Move_Deferred_Tax           => NULL
                                ,p_Link_To_Trx_Hist_Id         => NULL
                                ,
                                 --p_attribute_rec             => p_attribute_rec,
                                 --p_global_attribute_rec      => p_global_attribute_rec,
                                 p_Comments                     => NULL
                                ,p_Payment_Set_Id               => NULL
                                ,p_Application_Ref_Type         => NULL
                                ,p_Application_Ref_Id           => NULL
                                ,p_Application_Ref_Num          => NULL
                                ,p_Secondary_Application_Ref_Id => NULL
                                ,p_Application_Ref_Reason       => NULL
                                ,p_Customer_Reference           => NULL
                                ,p_Customer_Reason              => NULL);
      ELSE
      
        Ar_Receipt_Api_Pub.Apply(p_Api_Version                 => 1.0
                                ,p_Init_Msg_List               => NULL
                                ,p_Commit                      => NULL
                                ,p_Validation_Level            => NULL
                                ,x_Return_Status               => Lv_Ret_Status
                                ,x_Msg_Count                   => Ln_Msg_Count
                                ,x_Msg_Data                    => Lv_Msg_Data
                                ,p_Cash_Receipt_Id             => Rec_Apply.Receipt_Id
                                ,p_Receipt_Number              => NULL --Rec_Apply.Receipt_Number
                                ,p_Customer_Trx_Id             => Rec_Apply.Customer_Trx_Id
                                ,p_Trx_Number                  => NULL --Rec_Apply.Trx_Number
                                ,p_Installment                 => NULL
                                ,p_Applied_Payment_Schedule_Id => Rec_Apply.Payment_Schedule_Id
                                ,p_Amount_Applied              => Rec_Apply.Applied_Amount
                                ,p_Amount_Applied_From         => NULL
                                ,p_Trans_To_Receipt_Rate       => Rec_Apply.Currency_Conversion_Rate
                                ,p_Discount                    => NULL
                                ,p_Apply_Date                  => Rec_Apply.Applied_Date
                                ,p_Apply_Gl_Date               => Rec_Apply.Applied_Gl_Date
                                ,p_Ussgl_Transaction_Code      => NULL
                                ,p_Customer_Trx_Line_Id        => NULL
                                ,p_Line_Number                 => NULL
                                ,p_Show_Closed_Invoices        => NULL
                                ,p_Called_From                 => NULL
                                ,p_Move_Deferred_Tax           => NULL
                                ,p_Link_To_Trx_Hist_Id         => NULL
                                ,
                                 --p_attribute_rec             => p_attribute_rec,
                                 --p_global_attribute_rec      => p_global_attribute_rec,
                                 p_Comments                     => NULL
                                ,p_Payment_Set_Id               => NULL
                                ,p_Application_Ref_Type         => NULL
                                ,p_Application_Ref_Id           => NULL
                                ,p_Application_Ref_Num          => NULL
                                ,p_Secondary_Application_Ref_Id => NULL
                                ,p_Application_Ref_Reason       => NULL
                                ,p_Customer_Reference           => NULL
                                ,p_Customer_Reason              => NULL);
      END IF;
      --执行成功
      IF Lv_Ret_Status = Fnd_Api.g_Ret_Sts_Success THEN
      
        UPDATE Scux_Sie_Ar_Apply_Iface h
           SET h.Scux_Process_Step    = Lv_Procedure_Name
              ,h.Scux_Process_Status  = Gv_Completed
              ,h.Scux_Process_Date    = SYSDATE
              ,h.Scux_Process_Message = NULL
               --------------------------------------------------------
              ,h.Last_Updated_By        = Nvl(h.Last_Updated_By
                                             ,Gn_User_Id)
              ,h.Last_Update_Date       = SYSDATE
              ,h.Program_Application_Id = Fnd_Global.Prog_Appl_Id
              ,h.Program_Id             = Fnd_Global.Conc_Program_Id
              ,h.Program_Update_Date    = SYSDATE
              ,h.Request_Id             = Gn_Request_Id
        --------------------------------------------------------
         WHERE h.Scux_Interface_Header_Id =
               Rec_Apply.Scux_Interface_Header_Id;
      
        --执行失败
      ELSE
      
        Lv_Scux_Process_Message := Lv_Ret_Status || ':';
      
        --获取错误消息
        IF Ln_Msg_Count = 1 THEN
          --V1.1 MOD START --
          -- Lv_Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lv_Scux_Process_Message,Lv_Msg_Data); 
          Lv_Scux_Process_Message := Substr(Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lv_Scux_Process_Message
                                                                                  ,Lv_Msg_Data)
                                           ,1
                                           ,240);
          --V1.1 MOD END --
        ELSIF Ln_Msg_Count > 1 THEN
        
          FOR i IN 1 .. Ln_Msg_Count LOOP
            Fnd_Msg_Pub.Get(p_Msg_Index     => i
                           ,p_Encoded       => Fnd_Api.g_False
                           ,p_Data          => Lv_Msg_Data
                           ,p_Msg_Index_Out => Ln_Msg_Index_Out);
            --V1.1 MOD START --
            /*Lv_Scux_Process_Message := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lv_Scux_Process_Message
            ,Ln_Msg_Index_Out || '.' ||
             Lv_Msg_Data);*/
          
            Lv_Scux_Process_Message := Substr(Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lv_Scux_Process_Message
                                                                                    ,Ln_Msg_Index_Out || '.' ||
                                                                                     Lv_Msg_Data)
                                             ,1
                                             ,240);
            --V1.1 MOD END --
          END LOOP;
        
        END IF;
      
        UPDATE Scux_Sie_Ar_Apply_Iface h
           SET h.Scux_Process_Step    = Lv_Procedure_Name
              ,h.Scux_Process_Status  = Gv_Error
              ,h.Scux_Process_Date    = SYSDATE
              ,h.Scux_Process_Message = Lv_Scux_Process_Message
               --------------------------------------------------------
              ,h.Last_Updated_By        = Nvl(h.Last_Updated_By
                                             ,Gn_User_Id)
              ,h.Last_Update_Date       = SYSDATE
              ,h.Program_Application_Id = Fnd_Global.Prog_Appl_Id
              ,h.Program_Id             = Fnd_Global.Conc_Program_Id
              ,h.Program_Update_Date    = SYSDATE
              ,h.Request_Id             = Gn_Request_Id
        --------------------------------------------------------
         WHERE h.Scux_Interface_Header_Id =
               Rec_Apply.Scux_Interface_Header_Id;
      
      END IF;
    
      COMMIT;
    END LOOP;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Do_Trim_Data
  Author      :   SIE 高朋
  Created:    :   2018-10-01
  Purpose     :   去首尾空隔
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-01    SIE 高朋         Creation    
  ===============================================================*/
  PROCEDURE Do_Trim_Data(Pn_Scux_Session_Id  IN NUMBER
                        ,Pv_Scux_Source_Code IN VARCHAR
                        ,Xv_Ret_Status       OUT VARCHAR2
                        ,Xv_Ret_Message      OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Trim_Data';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Lv_Ret_Status     VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    Lv_Ret_Message    VARCHAR2(2000);
    v_Count           NUMBER;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    Gn_Main_Request_Id := Fnd_Global.Conc_Request_Id;
    UPDATE Scux_Sie_Ar_Apply_Iface
       SET Scux_Interface_Header_Id = TRIM(Scux_Interface_Header_Id)
          ,Scux_Session_Id          = TRIM(Scux_Session_Id)
          ,Scux_Source_Code         = TRIM(Scux_Source_Code)
          ,Scux_Source_Num          = TRIM(Scux_Source_Num)
          ,Scux_Source_Id           = TRIM(Scux_Source_Id)
          ,Scux_Process_Group_Id    = TRIM(Scux_Process_Group_Id)
          ,Scux_Process_Step        = Lv_Procedure_Name
          ,Scux_Process_Status      = Nvl(Scux_Process_Status
                                         ,Gv_Pending)
          ,Scux_Process_Date        = Nvl(TRIM(Scux_Process_Date)
                                         ,SYSDATE)
          ,Scux_Process_Message     = TRIM(Scux_Process_Message)
          ,Org_Id                   = TRIM(Org_Id)
          ,Scux_Org_Name            = TRIM(Scux_Org_Name)
          ,Receipt_Number           = TRIM(Receipt_Number)
          ,Receipt_Id               = TRIM(Receipt_Id)
          ,Applied_Amount           = TRIM(Applied_Amount)
           -- ,Applied_Date             = TRIM(Applied_Date)
           -- ,Applied_Gl_Date          = TRIM(Applied_Gl_Date)
          ,Trx_Number      = TRIM(Trx_Number)
          ,Customer_Trx_Id = TRIM(Customer_Trx_Id)
           
           --,Request_Id = Gn_Main_Request_Id --trim(Request_Id)
          ,Attribute1       = TRIM(Attribute1)
          ,Attribute2       = TRIM(Attribute2)
          ,Attribute3       = TRIM(Attribute3)
          ,Attribute4       = TRIM(Attribute4)
          ,Attribute5       = TRIM(Attribute5)
          ,Attribute6       = TRIM(Attribute6)
          ,Attribute7       = TRIM(Attribute7)
          ,Attribute8       = TRIM(Attribute8)
          ,Attribute9       = TRIM(Attribute9)
          ,Attribute10      = TRIM(Attribute10)
          ,Attribute11      = TRIM(Attribute11)
          ,Attribute12      = TRIM(Attribute12)
          ,Attribute13      = TRIM(Attribute13)
          ,Attribute14      = TRIM(Attribute14)
          ,Attribute15      = TRIM(Attribute15)
          ,Creation_Date    = Nvl(Creation_Date
                                 ,SYSDATE)
          ,Last_Updated_By  = Nvl(Last_Updated_By
                                 ,Gn_User_Id)
          ,Last_Update_Date = SYSDATE
    --,Scux_Create_Request_Id        = TRIM(Scux_Create_Request_Id)
    --,Scux_Post_Request_Id          = TRIM(Scux_Post_Request_Id)
     WHERE Scux_Session_Id = Pn_Scux_Session_Id
       AND Scux_Source_Code = Pv_Scux_Source_Code
       AND Nvl(Scux_Process_Status
              ,Gv_Pending) = Gv_Pending;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Do_Trim_Data;

  /*===============================================================
  Program Name:   Do_Import
  Author      :   SIE 高朋
  Created:    :   2018-10-01
  Purpose     :   AR收款核销发票导入主程序入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: AR收款核销发票导入主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-01    SIE 高朋         Creation    
  ===============================================================*/
  PROCEDURE Do_Import(Pn_Scux_Session_Id  IN NUMBER
                     ,Pv_Scux_Source_Code IN VARCHAR
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'Y' --是否初始化环境
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Import';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Lv_Ret_Status     VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    Lv_Ret_Message    VARCHAR2(2000);
    Lv_Ret_Msg_Count  NUMBER;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pv_Init_Flag = 'Y' THEN
      --初始化获取接口专用职责权限 SCUX_INTERFACE_SUPERUSER
      Scux_Fnd_Log.Step(Lv_Api
                       ,'0.初始化：-------------');
      Scux_Sie_Interface_Pkg.Apps_Initialize(Pv_Moac_Flag   => 'N'
                                            ,Xv_Ret_Status  => Xv_Ret_Status
                                            ,Xv_Ret_Message => Xv_Ret_Message);
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    
    END IF;
  
    Scux_Fnd_Log.Step(Lv_Api
                     ,'1.去除空格：-------------');
  
    Do_Trim_Data(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
                ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                ,Xv_Ret_Status       => Xv_Ret_Status
                ,Xv_Ret_Message      => Xv_Ret_Message);
    Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                  ,Pv_Status  => Xv_Ret_Status
                                  ,Pv_Message => Xv_Ret_Message);
    Scux_Fnd_Log.Step(Lv_Api
                     ,'2.验证数据：-------------');
    Validate_Data(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
                 ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                 ,Xv_Ret_Status       => Xv_Ret_Status
                 ,Xv_Ret_Message      => Xv_Ret_Message);
    Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                  ,Pv_Status  => Xv_Ret_Status
                                  ,Pv_Message => Xv_Ret_Message);
  
    Scux_Fnd_Log.Step(Lv_Api
                     ,'3.提交处理：-------------');
    Do_Apply(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
            ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
            ,Xv_Ret_Status       => Xv_Ret_Status
            ,Xv_Ret_Message      => Xv_Ret_Message);
    Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                  ,Pv_Status  => Xv_Ret_Status
                                  ,Pv_Message => Xv_Ret_Message);
  
    --将接口错误数据写入公用错误信息表
    Do_Set_Error(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
                ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                ,Xv_Ret_Status       => Xv_Ret_Status
                ,Xv_Ret_Message      => Xv_Ret_Message);
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
    
      --将接口错误数据写入公用错误信息表                                  
      Do_Set_Error(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
                  ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                  ,Xv_Ret_Status       => Xv_Ret_Status
                  ,Xv_Ret_Message      => Xv_Ret_Message);
  END;

  /*===============================================================
  Program Name:   Main
  Author      :   SIE 高朋
  Created:    :   2018-10-01
  Purpose     :   AR收款核销发票导入并发调用入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
              Pv_Debug_Flag        IN VARCHAR2 --开启诊段模试
              
  Return  :
              Errbuf               OUT VARCHAR2--状态
              Retcode              OUT VARCHAR2--错误信息
  Description: AR收款核销发票导入主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-10-01    SIE 高朋         Creation  
  V1.1      2018-12-17    SIE 郭剑         标准化修改  
  ===============================================================*/
  PROCEDURE Main(Errbuf              OUT VARCHAR2
                ,Retcode             OUT VARCHAR2
                ,Pn_Scux_Session_Id  IN NUMBER
                ,Pv_Scux_Source_Code IN VARCHAR
                ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'N' --是否初始化环境
                 ) IS
    Lv_Procedure_Name VARCHAR2(30) := 'MAIN';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    Lv_Ret_Status    VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    Lv_Ret_Message   VARCHAR2(2000);
    Ln_Ret_Msg_Count NUMBER;
  
  BEGIN
    Retcode := Scux_Fnd_Log.Gv_Retcode_Exc_Success;
    Scux_Fnd_Log.Conc_Log_Header;
  
    Gn_Main_Request_Id := Fnd_Global.Conc_Request_Id;
  
    Do_Import(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
             ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
             ,Pv_Init_Flag        => Pv_Init_Flag
             ,Xv_Ret_Status       => Lv_Ret_Status
             ,Xv_Ret_Message      => Lv_Ret_Message);
    Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Lv_Ret_Status
                                      ,Pv_Ret_Message => Lv_Ret_Message --V1.1 MOD
                                       );
  
    Scux_Fnd_Log.Conc_Log_Footer;
  EXCEPTION
    --Standard SRS Main Exception Handler
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Srs_Exception(Pv_Api  => Lv_Api
                                             ,Errbuf  => Errbuf
                                             ,Retcode => Retcode);
  END Main;

END Scux_Sie_Ar_Apply_Imp_Pkg;
/
