CREATE OR REPLACE PACKAGE Scux_Sie_Ar_Unapply_Cm_Imp_Pkg IS
  /*=============================================================
  Copyright (C)  SIE Consulting Co., Ltd    
  All rights reserved 
  ===============================================================
  Program Name:   Scux_Sie_AR_Unapply_Cm_Imp_Pkg
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   
  Description : 标准化应收贷项发票取消核销程序主程序（版本管控）
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0     2018-09-19    SIE 谭家俊        Creation
  ===============================================================*/

  /*===============================================================
  Program Name:   Do_Import
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   应收贷项发票取消核销程序入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 应收贷项发票取消核销主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-07-25    SIE 谭家俊         Creation    
  V1.1      2018-12-17    SIE 郭剑           标准化修改
  ===============================================================*/
  PROCEDURE Do_Import(Pn_Scux_Session_Id  IN NUMBER
                     ,Pv_Scux_Source_Code IN VARCHAR
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'Y' --是否初始化环境
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2);

  /*===============================================================
  Program Name:   Main
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   应收贷项发票取消核销程序并发调用入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
  Return  :
              Errbuf               OUT VARCHAR2--状态
              Retcode              OUT VARCHAR2--错误信息
  Description: 应收贷项发票取消核销程序主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Main(Errbuf              OUT VARCHAR2
                ,Retcode             OUT VARCHAR2
                ,Pn_Scux_Session_Id  IN NUMBER
                ,Pv_Scux_Source_Code IN VARCHAR
                ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'N' --是否初始化环境
                 );
END Scux_Sie_Ar_Unapply_Cm_Imp_Pkg;
/
CREATE OR REPLACE PACKAGE BODY Scux_Sie_Ar_Unapply_Cm_Imp_Pkg IS
  Gv_Package_Name CONSTANT VARCHAR2(30) := 'Scux_Sie_Ar_Unapply_Cm_Imp_Pkg';

  Gv_Pending CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Pending; -- 'PENDING'; --待定
  Gv_Running CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Running; -- 'RUNNING'; --运行中
  --Gv_Submit    CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Submit; -- 'SUBMIT'; --已提交(用于异步调用并发请求中间状态
  Gv_Completed CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Completed; -- 'COMPLETED'; --已完成
  Gv_Error     CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Error; -- 'ERROR'; --错误

  Gn_User_Id         NUMBER := Fnd_Global.User_Id;
  Gn_Main_Request_Id NUMBER; --主程序并发请求ID

  Gv_Application_Code CONSTANT VARCHAR2(30) := Scux_Fnd_Log.Gv_Application_Code; --ADD BY SIE 谭家俊 2018/8/31

  /*===============================================================
  Program Name:   Get_Created_By
  Author      :   SIE 谭家俊
  Created:    :   2018-07-27
  Purpose     :   获取创建人
  Parameters  :
              Pv_Created_Name           IN VARCHAR2   --用户帐号名称
  
  Return  :
              EBS用户ID
  Description: 
            1.先跟据员工信息与EBS帐号关联去找
            2.上条件未找到根据EBS帐号去找
            3.以上条件都不满足取当前执行帐号
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-07-27    SIE 谭家俊         Creation  
  V1.1      2018-11-26    SIE 郭剑           Pv_Created_Name  取值Created_By 为id当前逻辑给调用者可能带来误解 
  ===============================================================*/
  FUNCTION Get_Created_By(Pv_Created_Name VARCHAR2) RETURN NUMBER IS
    Ln_Created_By NUMBER;
  BEGIN
    SELECT Fu.User_Id
      INTO Ln_Created_By
      FROM Fnd_User     Fu
          ,Per_People_f Ppf
     WHERE Fu.Employee_Id = Ppf.Person_Id
          --AND Ppf.Last_Name = Pv_Created_Name
       AND Ppf.Employee_Number = Pv_Created_Name
       AND SYSDATE BETWEEN Effective_Start_Date AND
           Nvl(Effective_End_Date
              ,Hr_General.End_Of_Time);
    RETURN Ln_Created_By;
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        SELECT Fu.User_Id
          INTO Ln_Created_By
          FROM Fnd_User Fu
         WHERE Fu.User_Name = Pv_Created_Name;
        RETURN Ln_Created_By;
      EXCEPTION
        WHEN OTHERS THEN
          --V1.1 Add start ----------------- 
          BEGIN
            SELECT Fu.User_Id
              INTO Ln_Created_By
              FROM Fnd_User Fu
             WHERE Fu.User_Id = To_Number(Pv_Created_Name);
            RETURN Ln_Created_By;
            -- Ln_Created_By := Gn_User_Id;
            --V1.1 Add end ----------------- 
          EXCEPTION
            WHEN OTHERS THEN
              RETURN NULL;
          END;
      END;
  END;

  /*===============================================================
  Program Name:   Get_Str_Num
  Author      :   SIE 谭家俊
  Created:    :   2018-09-18
  Purpose     :   获取字窜有多少个拽定字符
  Parameters  :
              Pv_Chr   VARCHAR2  --字窜
              Pv_Div   VARCHAR2  --特定单一字符 
  Return  :
              特定单一字符  数量
  Description: 
            
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-18    SIE 谭家俊         Creation    
  ===============================================================*/
  FUNCTION Get_Str_Num(Pv_Chr VARCHAR2
                      ,Pv_Div VARCHAR2) RETURN NUMBER IS
    --Ln_Created_By NUMBER;
    Ln_Length_Max NUMBER;
    --Ln_Length     NUMBER;
    Ln_Cnt NUMBER;
  BEGIN
    Ln_Length_Max := Length(Pv_Chr);
    Ln_Cnt        := 0;
    FOR i IN 1 .. Ln_Length_Max LOOP
      IF Substr(Pv_Chr
               ,i
               ,1) = Pv_Div THEN
        Ln_Cnt := Ln_Cnt + 1;
      END IF;
    END LOOP;
    RETURN Ln_Cnt;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  /*===============================================================
  Program Name:   Validate_Org
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   验证业务实体
  Parameters  :
              Pn_org_Id            IN NUMBER    --业务实体ID
              Pv_Org_Name          IN VARCHAR2  --业务实体名称
  
  Return  :
              Xn_Org_Id            OUT NUMBER    --业务实体ID
              Xv_Ret_Status           OUT VARCHAR2  --状态
              Xv_Ret_Message          OUT VARCHAR2  --错误信息
  Description: 
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Validate_Org(Pn_Org_Id      IN NUMBER
                        ,Pv_Org_Name    IN VARCHAR2
                        ,Xn_Org_Id      OUT NUMBER
                        ,Xv_Ret_Status  OUT VARCHAR2
                        ,Xv_Ret_Message OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Org';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    --Pn_org_Id Pv_Org_Name 不能同时为空
    IF Pn_Org_Id IS NULL
       AND Pv_Org_Name IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Pn_org_Id/Pv_Org_Name');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
  
    BEGIN
    
      IF Pn_Org_Id IS NOT NULL
         AND Pv_Org_Name IS NOT NULL THEN
        SELECT Hou.Organization_Id
          INTO Xn_Org_Id
          FROM Hr_Operating_Units Hou
         WHERE 1 = 1
           AND Hou.Name = Pv_Org_Name
           AND Hou.Organization_Id = Pn_Org_Id;
      
      ELSIF Pn_Org_Id IS NOT NULL THEN
        SELECT Hou.Organization_Id
          INTO Xn_Org_Id
          FROM Hr_Operating_Units Hou
         WHERE 1 = 1
           AND Hou.Organization_Id = Pn_Org_Id;
      
      ELSIF Pv_Org_Name IS NOT NULL THEN
        SELECT Hou.Organization_Id
          INTO Xn_Org_Id
          FROM Hr_Operating_Units Hou
         WHERE 1 = 1
           AND Hou.Name = Pv_Org_Name;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AHL'
                                                       ,Pv_Message_Name     => 'AHL_OSP_ORD_INV_OPUNIT'
                                                       ,Pv_Token1           => NULL
                                                       ,Pv_Value1           => NULL);
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Xv_Ret_Status
                                      ,Pv_Message => Xv_Ret_Message);
    END;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api         => Lv_Api
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
    
  END Validate_Org;

  /*===============================================================
  Program Name:   Validate_Cm_Customer_Trx
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   验证贷项通知单
  Parameters  :
              Pn_Cm_Customer_Trx_Id IN NUMBER   --贷项通知单id
              Pv_Cm_Trx_Number      IN VARCHAR2 --贷项通知单号
              Pn_org_Id            IN NUMBER    --业务实体ID
              
  
  Return  :
              Xn_Org_Id            OUT NUMBER    --业务实体ID
              Xv_Ret_Status           OUT VARCHAR2  --状态
              Xv_Ret_Message          OUT VARCHAR2  --错误信息
  Description: 
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Validate_Cm_Customer_Trx(Pn_Cm_Customer_Trx_Id IN NUMBER
                                    ,Pv_Cm_Trx_Number      IN VARCHAR2
                                    ,Pn_Org_Id             IN NUMBER
                                    ,Xn_Cm_Customer_Trx_Id OUT NUMBER
                                    ,Xv_Ret_Status         OUT VARCHAR2
                                    ,Xv_Ret_Message        OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Ledger';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    --Pn_Cm_Customer_Trx_Id Pv_Cm_Trx_Number 不能同时为空
    IF Pn_Cm_Customer_Trx_Id IS NULL
       AND Pv_Cm_Trx_Number IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Pn_Cm_Customer_Trx_Id/Pv_Cm_Trx_Number');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
    BEGIN
    
      IF Pn_Cm_Customer_Trx_Id IS NOT NULL
         AND Pv_Cm_Trx_Number IS NOT NULL THEN
        SELECT Rct.Customer_Trx_Id
          INTO Xn_Cm_Customer_Trx_Id
          FROM Ra_Customer_Trx_All      Rct
              ,Ar_Payment_Schedules_All Aps
              ,Ra_Cust_Trx_Types_All    Rtt
         WHERE Aps.Customer_Trx_Id = Rct.Customer_Trx_Id
           AND Rct.Cust_Trx_Type_Id = Rtt.Cust_Trx_Type_Id
           AND Rct.Org_Id = Rtt.Org_Id
           AND Rtt.Type = 'CM'
           AND Rct.Status_Trx = 'OP'
           AND Rct.Org_Id = Pn_Org_Id
           AND Rct.Trx_Number = Pv_Cm_Trx_Number;
      
      ELSIF Pn_Cm_Customer_Trx_Id IS NOT NULL THEN
        SELECT Ra.Customer_Trx_Id
          INTO Xn_Cm_Customer_Trx_Id
          FROM Ra_Customer_Trx_All Ra
         WHERE 1 = 1
           AND Ra.Org_Id = Pn_Org_Id
           AND Ra.Customer_Trx_Id = Pn_Cm_Customer_Trx_Id;
      
      ELSIF Pv_Cm_Trx_Number IS NOT NULL THEN
        SELECT Rct.Customer_Trx_Id
          INTO Xn_Cm_Customer_Trx_Id
          FROM Ra_Customer_Trx_All      Rct
              ,Ar_Payment_Schedules_All Aps
              ,Ra_Cust_Trx_Types_All    Rtt
         WHERE Aps.Customer_Trx_Id = Rct.Customer_Trx_Id
           AND Rct.Cust_Trx_Type_Id = Rtt.Cust_Trx_Type_Id
           AND Rct.Org_Id = Rtt.Org_Id
           AND Rtt.Type = 'CM'
           AND Rct.Status_Trx = 'OP'
           AND Rct.Org_Id = Pn_Org_Id
           AND Rct.Trx_Number = Pv_Cm_Trx_Number;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AR'
                                                       ,Pv_Message_Name     => 'AR_BPA_TRX_NOT_FOUND' --无法找到事务处理 "&TRANSACTION_NUMBER"。
                                                       ,Pv_Token1           => 'TRANSACTION_NUMBER'
                                                       ,Pv_Value1           => Pv_Cm_Trx_Number);
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Xv_Ret_Status
                                      ,Pv_Message => Xv_Ret_Message);
    END;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api         => Lv_Api
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
    
  END Validate_Cm_Customer_Trx;

  /*===============================================================
  Program Name:   Validate_Inv_Customer_Trx
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   验证AR发票
  Parameters  :
              Pn_Inv_Customer_Trx_Id IN NUMBER --AR发票ID
              Pv_Inv_Trx_Number     IN VARCHAR2 --AR发票号
              Pn_org_Id              IN NUMBER    --业务实体ID
  
  Return  :
              Xn_Org_Id            OUT NUMBER    --业务实体ID
              Xv_Ret_Status           OUT VARCHAR2  --状态
              Xv_Ret_Message          OUT VARCHAR2  --错误信息
  Description: 
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Validate_Inv_Customer_Trx(Pn_Inv_Customer_Trx_Id IN NUMBER
                                     ,Pv_Inv_Trx_Number      IN VARCHAR2
                                     ,Pn_Org_Id              IN NUMBER
                                     ,Xn_Inv_Customer_Trx_Id OUT NUMBER
                                     ,Xv_Ret_Status          OUT VARCHAR2
                                     ,Xv_Ret_Message         OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Ledger';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    --Pn_Inv_Customer_Trx_Id Pv_Inv_Trx_Number 不能同时为空
    IF Pn_Inv_Customer_Trx_Id IS NULL
       AND Pv_Inv_Trx_Number IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --不能为空
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Pn_Inv_Customer_Trx_Id/Pv_Inv_Trx_Number');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
  
    BEGIN
    
      IF Pn_Inv_Customer_Trx_Id IS NOT NULL
         AND Pv_Inv_Trx_Number IS NOT NULL THEN
      
        SELECT Rct.Customer_Trx_Id
          INTO Xn_Inv_Customer_Trx_Id
          FROM Ra_Customer_Trx_All      Rct
              ,Ar_Payment_Schedules_All Aps
              ,Ra_Cust_Trx_Types_All    Rtt
         WHERE Aps.Customer_Trx_Id = Rct.Customer_Trx_Id
           AND Rct.Cust_Trx_Type_Id = Rtt.Cust_Trx_Type_Id
           AND Rct.Org_Id = Rtt.Org_Id
           AND Rtt.Type NOT IN ('CM')
           AND Rct.Org_Id = Pn_Org_Id
           AND Rct.Trx_Number = Pv_Inv_Trx_Number;
      
      ELSIF Pn_Inv_Customer_Trx_Id IS NOT NULL THEN
        SELECT Ra.Customer_Trx_Id
          INTO Xn_Inv_Customer_Trx_Id
          FROM Ra_Customer_Trx_All Ra
         WHERE 1 = 1
           AND Ra.Customer_Trx_Id = Pn_Inv_Customer_Trx_Id
           AND Ra.Org_Id = Pn_Org_Id;
      ELSIF Pv_Inv_Trx_Number IS NOT NULL THEN
      
        SELECT Rct.Customer_Trx_Id
          INTO Xn_Inv_Customer_Trx_Id
          FROM Ra_Customer_Trx_All      Rct
              ,Ar_Payment_Schedules_All Aps
              ,Ra_Cust_Trx_Types_All    Rtt
         WHERE Aps.Customer_Trx_Id = Rct.Customer_Trx_Id
           AND Rct.Cust_Trx_Type_Id = Rtt.Cust_Trx_Type_Id
           AND Rct.Org_Id = Rtt.Org_Id
           AND Rtt.Type NOT IN ('CM')
           AND Rct.Trx_Number = Pv_Inv_Trx_Number
           AND Rct.Org_Id = Pn_Org_Id;
      END IF;
    
    EXCEPTION
      WHEN OTHERS THEN
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AR'
                                                       ,Pv_Message_Name     => 'AR_BPA_TRX_NOT_FOUND' --无法找到事务处理 "&TRANSACTION_NUMBER"。
                                                       ,Pv_Token1           => 'TRANSACTION_NUMBER'
                                                       ,Pv_Value1           => Pv_Inv_Trx_Number);
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Xv_Ret_Status
                                      ,Pv_Message => Xv_Ret_Message);
    END;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Sie_Interface_Pkg.Validate_Exception(Pv_Api         => Lv_Api
                                               ,Xv_Ret_Status  => Xv_Ret_Status
                                               ,Xv_Ret_Message => Xv_Ret_Message);
    
  END Validate_Inv_Customer_Trx;

  /*===============================================================
  Program Name:   Validate_Scux_Created_Name
  Author      :   SIE 谭家俊
  Created:    :   2018-07-27
  Purpose     :   验证用户名
  Parameters  :
              Pv_Scux_Created_Name    IN VARCHAR2  --用户名
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.1      2018-07-27    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Validate_Scux_Created_Name(Pv_Scux_Created_Name IN VARCHAR2
                                      ,Xn_Created_By        OUT NUMBER
                                      ,Xv_Ret_Status        OUT VARCHAR2
                                      ,Xv_Ret_Message       OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Scux_Created_Name';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    --Ln_Count NUMBER;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pv_Scux_Created_Name IS NULL THEN
      Xn_Created_By := Gn_User_Id;
    ELSE
      Xn_Created_By := Get_Created_By(Pv_Scux_Created_Name);
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
  END Validate_Scux_Created_Name;

  /*===============================================================
  Program Name:   Validate_Data
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
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
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  V1.1      2018-12-17    SIE 郭剑           消息长度可能错误修正
  ===============================================================*/
  PROCEDURE Validate_Data(Pn_Scux_Session_Id  IN NUMBER
                         ,Pv_Scux_Source_Code IN VARCHAR
                         ,Xv_Ret_Status       OUT VARCHAR2
                         ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Data';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Lv_Ret_Status     VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    Lv_Ret_Message    VARCHAR2(2000);
  
    CURSOR Csr_Create_Data IS
      SELECT h.Rowid Row_Id
            ,h.*
        FROM Scux_Sie_Ar_Unapp_Cm_Iface h
       WHERE h.Scux_Session_Id = Pn_Scux_Session_Id
         AND h.Scux_Source_Code = Pv_Scux_Source_Code
         AND h.Scux_Process_Status = Gv_Pending;
  
    TYPE Lt_Rec IS RECORD(
       Scux_Org_Id         Scux_Sie_Ar_Unapp_Cm_Iface.Scux_Org_Id%TYPE
      ,Cm_Customer_Trx_Id  Scux_Sie_Ar_Unapp_Cm_Iface.Cm_Customer_Trx_Id%TYPE
      ,Inv_Customer_Trx_Id Scux_Sie_Ar_Unapp_Cm_Iface.Inv_Customer_Trx_Id%TYPE
      ,Created_By          Scux_Sie_Ar_Unapp_Cm_Iface.Created_By%TYPE
      ,Header_Status       VARCHAR2(1)
      ,Header_Error_Code   VARCHAR2(30)
      ,Header_Error_Msg    VARCHAR2(2000));
  
    Lt_Tmp_Rec Lt_Rec;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    FOR Rec_Header IN Csr_Create_Data LOOP
      Lt_Tmp_Rec               := NULL;
      Lt_Tmp_Rec.Header_Status := Fnd_Api.g_Ret_Sts_Success;
      Lv_Ret_Status            := NULL;
      Lv_Ret_Message           := NULL;
    
      --1.验证业务实体    
      Validate_Org(Pn_Org_Id      => Rec_Header.Scux_Org_Id
                  ,Pv_Org_Name    => Rec_Header.Scux_Org_Name
                  ,Xn_Org_Id      => Lt_Tmp_Rec.Scux_Org_Id
                  ,Xv_Ret_Status  => Lv_Ret_Status
                  ,Xv_Ret_Message => Lv_Ret_Message);
    
      IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        Lt_Tmp_Rec.Header_Status    := Lv_Ret_Status;
        Lt_Tmp_Rec.Header_Error_Msg := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Tmp_Rec.Header_Error_Msg
                                                                             ,Lv_Ret_Message);
      END IF;
      --2.验证贷项通知单
      Validate_Cm_Customer_Trx(Pn_Cm_Customer_Trx_Id => Rec_Header.Cm_Customer_Trx_Id
                              ,Pv_Cm_Trx_Number      => Rec_Header.Cm_Trx_Number
                              ,Pn_Org_Id             => Lt_Tmp_Rec.Scux_Org_Id
                              ,Xn_Cm_Customer_Trx_Id => Lt_Tmp_Rec.Cm_Customer_Trx_Id
                              ,Xv_Ret_Status         => Lv_Ret_Status
                              ,Xv_Ret_Message        => Lv_Ret_Message);
      IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        Lt_Tmp_Rec.Header_Status    := Lv_Ret_Status;
        Lt_Tmp_Rec.Header_Error_Msg := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Tmp_Rec.Header_Error_Msg
                                                                             ,Lv_Ret_Message);
      END IF;
    
      --4.验证AR发票
      Validate_Inv_Customer_Trx(Pn_Inv_Customer_Trx_Id => Rec_Header.Inv_Customer_Trx_Id
                               ,Pv_Inv_Trx_Number      => Rec_Header.Inv_Trx_Number
                               ,Pn_Org_Id              => Lt_Tmp_Rec.Scux_Org_Id
                               ,Xn_Inv_Customer_Trx_Id => Lt_Tmp_Rec.Inv_Customer_Trx_Id
                               ,Xv_Ret_Status          => Lv_Ret_Status
                               ,Xv_Ret_Message         => Lv_Ret_Message);
      IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        Lt_Tmp_Rec.Header_Status    := Lv_Ret_Status;
        Lt_Tmp_Rec.Header_Error_Msg := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Tmp_Rec.Header_Error_Msg
                                                                             ,Lv_Ret_Message);
      END IF;
    
      --15.验证创建用户
      Validate_Scux_Created_Name(Pv_Scux_Created_Name => Rec_Header.Created_By
                                ,Xn_Created_By        => Lt_Tmp_Rec.Created_By
                                ,Xv_Ret_Status        => Lv_Ret_Status
                                ,Xv_Ret_Message       => Lv_Ret_Message);
      IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        Lt_Tmp_Rec.Header_Status    := Lv_Ret_Status;
        Lt_Tmp_Rec.Header_Error_Msg := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Tmp_Rec.Header_Error_Msg
                                                                             ,Lv_Ret_Message);
      END IF;
      --Local_Customs_dev  SIE 谭家俊 2018-7-25 begin--------
      --来地化程序调用示例
      /*Local_Customs_001(Pv_Attribute9  => Rec_Header.Attribute9
                        ,Xv_Ret_Status        => Lv_Ret_Status
                        ,Xv_Ret_Message       => Lv_Ret_Message);
      
      Lt_Tmp_Rec.Header_Status    := Lv_Ret_Status;
      Lt_Tmp_Rec.Header_Error_Msg := Scux_Sie_Interface_Pkg.Merge_Error_Msg(Lt_Tmp_Rec.Header_Error_Msg
                                                                           ,Lv_Ret_Message);*/
      --Local_Customs_dev end--------                                                            
    
      IF Lt_Tmp_Rec.Header_Status = Fnd_Api.g_Ret_Sts_Success THEN
        UPDATE Scux_Sie_Ar_Unapp_Cm_Iface h
           SET h.Scux_Process_Status  = Gv_Running
              ,h.Scux_Process_Message = NULL
              ,h.Scux_Process_Date    = SYSDATE
              ,h.Scux_Process_Step    = Lv_Procedure_Name
              ,h.Scux_Org_Id          = Lt_Tmp_Rec.Scux_Org_Id
              ,h.Created_By           = Lt_Tmp_Rec.Created_By
              ,h.Cm_Customer_Trx_Id   = Lt_Tmp_Rec.Cm_Customer_Trx_Id
              ,h.Inv_Customer_Trx_Id  = Lt_Tmp_Rec.Inv_Customer_Trx_Id
         WHERE ROWID = Rec_Header.Row_Id;
      
      ELSE
        --验证失败        
        UPDATE Scux_Sie_Ar_Unapp_Cm_Iface h
           SET Scux_Process_Status  = Gv_Error
              ,Scux_Process_Message = Substr(Lt_Tmp_Rec.Header_Error_Msg
                                            ,1
                                            ,240) --V1.1 Lt_Tmp_Rec.Header_Error_Msg
              ,h.Scux_Process_Date  = SYSDATE
              ,h.Scux_Process_Step  = Lv_Procedure_Name
         WHERE ROWID = Rec_Header.Row_Id;
      
      END IF;
    
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
  END Validate_Data;

  /*===============================================================
  Program Name:   Do_Set_Error
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   将错误信息推送到错误公用记录表
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
  
  Description: 将错误信息推送到错误公用记录表 Scux_Sie_Interface_Errors
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Do_Set_Error(Pn_Scux_Session_Id  IN NUMBER
                        ,Pv_Scux_Source_Code IN VARCHAR2
                        ,Xv_Ret_Status       IN OUT VARCHAR2
                        ,Xv_Ret_Message      IN OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Set_Error';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    CURSOR Crs_Scux_Std_Column IS
      SELECT Cgi.Scux_Interface_Header_Id
            ,Cgi.Scux_Session_Id
            ,Cgi.Scux_Source_Code
            ,Cgi.Scux_Source_Num
            ,Cgi.Scux_Source_Id
            ,Cgi.Scux_Process_Group_Id
            ,Cgi.Scux_Process_Step
            ,Cgi.Scux_Process_Status
            ,Cgi.Scux_Process_Date
            ,Cgi.Scux_Process_Message
        FROM Scux_Sie_Ar_Unapp_Cm_Iface Cgi
       WHERE Cgi.Scux_Process_Status = Gv_Error
         AND Cgi.Scux_Source_Code = Pv_Scux_Source_Code
         AND Cgi.Scux_Session_Id = Pn_Scux_Session_Id;
  
    Lr_Scux_Std_Column Scux_Sie_Interface_Pkg.Gr_Scux_Std_Column;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Xv_Ret_Status = Fnd_Api.g_Ret_Sts_Success THEN
    
      FOR Rec_Line IN Crs_Scux_Std_Column LOOP
        Lr_Scux_Std_Column.Scux_Interface_Header_Id := Rec_Line.Scux_Interface_Header_Id;
        Lr_Scux_Std_Column.Scux_Session_Id          := Rec_Line.Scux_Session_Id;
        Lr_Scux_Std_Column.Scux_Source_Code         := Rec_Line.Scux_Source_Code;
        Lr_Scux_Std_Column.Scux_Source_Num          := Rec_Line.Scux_Source_Num;
        Lr_Scux_Std_Column.Scux_Source_Id           := Rec_Line.Scux_Source_Id;
        Lr_Scux_Std_Column.Scux_Process_Group_Id    := Rec_Line.Scux_Process_Group_Id;
        Lr_Scux_Std_Column.Scux_Process_Step        := Rec_Line.Scux_Process_Step;
        Lr_Scux_Std_Column.Scux_Process_Status      := Rec_Line.Scux_Process_Status;
        Lr_Scux_Std_Column.Scux_Process_Date        := Rec_Line.Scux_Process_Date;
        Lr_Scux_Std_Column.Scux_Process_Message     := Substrb(Rec_Line.Scux_Process_Message
                                                              ,0
                                                              ,240);
      
        Scux_Sie_Interface_Pkg.Set_Error(Pv_Source_Code     => Gv_Package_Name
                                        ,Pv_Table_Name      => 'SCUX_SIE_AR_UNAPP_CM_IFACE'
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
  Program Name:   Do_Unapply_CM_Invoice
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   取消贷项发票核销
  Parameters  :
              Pv_Cm_Trx_Number   IN VARCHAR2   --贷项发票编号
              Pn_Cm_Customer_Trx_Id  IN NUMBER --贷项发票ID
              Pv_Inv_Trx_Number      IN VARCHAR2 --应收发票编号
              Pn_Inv_Customer_Trx_Id IN NUMBER --应收发票ID
              
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Do_Unapply_Cm_Invoice(Pn_Org_Id              IN NUMBER
                                 ,Pv_Cm_Trx_Number       IN VARCHAR2
                                 ,Pn_Cm_Customer_Trx_Id  IN NUMBER
                                 ,Pv_Inv_Trx_Number      IN VARCHAR2
                                 ,Pn_Inv_Customer_Trx_Id IN NUMBER
                                 ,Pd_Reversal_Gl_Date    IN DATE
                                 ,Xv_Ret_Status          OUT VARCHAR2
                                 ,Xv_Ret_Message         OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Unapply_Cm_Invoice';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Ln_Api_Version   CONSTANT NUMBER := 1;
    Lb_Init_Msg_List CONSTANT VARCHAR2(1) := Fnd_Api.g_False;
    Lb_Commit        CONSTANT VARCHAR2(1) := Fnd_Api.g_False;
    Lr_Cm_Unapp_Rec           Ar_Cm_Api_Pub.Cm_Unapp_Rec_Type;
    Ln_Msg_Count              NUMBER;
    Lv_Msg_Data               VARCHAR2(2000);
    Ln_Out_Rec_Application_Id NUMBER;
    Lv_Return_Status          VARCHAR2(1);
  
    CURSOR Csr_Receivable_Application_Id(Pn_Cm_Customer_Trx_Id  IN NUMBER
                                        ,Pn_Inv_Customer_Trx_Id IN NUMBER) IS
      SELECT Receivable_Application_Id
        FROM Ar_Receivable_Applications_All Ra
       WHERE Customer_Trx_Id = Pn_Cm_Customer_Trx_Id
         AND Applied_Customer_Trx_Id = Pn_Inv_Customer_Trx_Id
       ORDER BY Ra.Receivable_Application_Id DESC;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
  
    /* IMPORTANT: Before calling the API, you need properly initialize org/user/resp information, otherwise the API will fail.
       Please read the following instructions to set these properly.
    
    1. Setting Org Context
       Oracle Application tables are striped by Org, and you first need to identify what org you are processing in
       The procedure to set Org has changed between R11.5 and R12:
    
       R11.5: fnd_client_info.set_org_context(&org_id);
    
       R12: Mo_global.init('AR'); 
            Mo_global.set_policy_context('S', 204); 
    
    2. User/Responsibility Information
       Before running the API, you need to provide your login credentials using fnd_global.apps_initialize()
       This procedure requires three parameters: UserId, ResponsibilityId, applicationId
       See Step 1. above to get the proper values and use them in the following line of code
    */
  
    -- Set Org Context
    -- see instructions above to identify what call you need to use, and uncomment that line below.
    -- if you are on R11.5, remove the -- in the following line:
    -- fnd_client_info.set_org_context(&org_id);
  
    -- if you are on R12, remove the -- in the next 2 lines:
    Mo_Global.Init('AR');
    Mo_Global.Set_Policy_Context('S'
                                ,Pn_Org_Id);
  
    -- Set User/Resp
    --Fnd_Global.Apps_Initialize(&User_Id, &Responsibility_Id, 222)
  
    Lr_Cm_Unapp_Rec.Cm_Customer_Trx_Id := Pn_Cm_Customer_Trx_Id; --&Credit_Memo_Customer_Trx_Id;
    --Lr_Cm_Unapp_Rec.Cm_Trx_Number               := Pv_Cm_Trx_Number; --NULL; -- Credit Memo Number
    Lr_Cm_Unapp_Rec.Inv_Customer_Trx_Id := Pn_Inv_Customer_Trx_Id; --&Invoice_Memo_Customer_Trx_Id;
    -- Lr_Cm_Unapp_Rec.Inv_Trx_Number              := Pv_Inv_Trx_Number; --NULL; -- Invoice Number
    Lr_Cm_Unapp_Rec.Installment                 := NULL;
    Lr_Cm_Unapp_Rec.Applied_Payment_Schedule_Id := NULL;
    /*BEGIN
      SELECT Receivable_Application_Id
        INTO Ln_Out_Rec_Application_Id
        FROM Ar_Receivable_Applications_All
       WHERE Customer_Trx_Id = Pn_Cm_Customer_Trx_Id --&Credit_Memo_Customer_Trx_Id
         AND Applied_Customer_Trx_Id = Pn_Inv_Customer_Trx_Id; --&Invoice_Customer_Trx_Id;
    EXCEPTION
      WHEN OTHERS THEN
        Ln_Out_Rec_Application_Id := NULL;
    END;*/
    --取最新的一笔活动记录ID
    OPEN Csr_Receivable_Application_Id(Pn_Cm_Customer_Trx_Id
                                      ,Pn_Inv_Customer_Trx_Id);
    FETCH Csr_Receivable_Application_Id
      INTO Ln_Out_Rec_Application_Id;
    CLOSE Csr_Receivable_Application_Id;
  
    IF Ln_Out_Rec_Application_Id IS NOT NULL THEN
    
      Lr_Cm_Unapp_Rec.Receivable_Application_Id := Ln_Out_Rec_Application_Id; --&Receivable_Application_Id;
      Lr_Cm_Unapp_Rec.Reversal_Gl_Date          := Nvl(Pd_Reversal_Gl_Date
                                                      ,Trunc(SYSDATE));
      Lr_Cm_Unapp_Rec.Called_From               := NULL;
    
      Ar_Cm_Api_Pub.Unapply_On_Account(p_Api_Version   => Ln_Api_Version
                                      ,p_Init_Msg_List => Lb_Init_Msg_List
                                      ,p_Commit        => Lb_Commit
                                      ,p_Cm_Unapp_Rec  => Lr_Cm_Unapp_Rec
                                      ,x_Return_Status => Lv_Return_Status
                                      ,x_Msg_Count     => Ln_Msg_Count
                                      ,x_Msg_Data      => Lv_Msg_Data);
      --Dbms_Output.Put_Line('return_status: ' || lv_Return_Status);
      -- Dbms_Output.Put_Line('msg_count: ' || ln_Msg_Count);
    
      Lv_Msg_Data := '';
    
      IF Ln_Msg_Count = 1 THEN
        -- Dbms_Output.Put_Line(Lv_Msg_Data);
        Xv_Ret_Message := Lv_Msg_Data;
      ELSIF Ln_Msg_Count > 1 THEN
      
        FOR i IN 1 .. Ln_Msg_Count LOOP
          Lv_Msg_Data := Lv_Msg_Data || i || '. ' ||
                         Substr(Fnd_Msg_Pub.Get(p_Encoded => Fnd_Api.g_False)
                               ,1
                               ,255);
          --Dbms_Output.Put_Line(i || '. ' || Substr(Fnd_Msg_Pub.Get(p_Encoded => Fnd_Api.g_False), 1, 255));
        END LOOP;
      
      END IF;
    
    ELSE
    
      Lv_Msg_Data := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AR'
                                                  ,Pv_Message_Name     => 'AR_TAPI_RELATED_NOT_ALLOWED'
                                                  ,Pv_Token1           => NULL
                                                  ,Pv_Value1           => NULL);
    END IF;
  
    IF Lv_Msg_Data IS NOT NULL THEN
      Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Error;
    END IF;
  
    Xv_Ret_Message := Lv_Msg_Data;
  
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Do_Unapply_Cm_Invoice;

  /*===============================================================
  Program Name:   Do_Process_Interface
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   插入接口表
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
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Do_Process_Interface(Pn_Scux_Session_Id  IN NUMBER
                                ,Pv_Scux_Source_Code IN VARCHAR
                                ,Xv_Ret_Status       OUT VARCHAR2
                                ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_process_Interface';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    Lv_Ret_Status     VARCHAR2(30);
    Lv_Ret_Msg        VARCHAR2(2000);
    CURSOR Crs_Data IS
      SELECT h.Rowid Row_Id
            ,h.*
        FROM Scux_Sie_Ar_Unapp_Cm_Iface h
       WHERE h.Scux_Session_Id = Pn_Scux_Session_Id
         AND h.Scux_Source_Code = Pv_Scux_Source_Code
         AND h.Scux_Process_Status = Gv_Running;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    FOR Lr_Recode IN Crs_Data LOOP
      Do_Unapply_Cm_Invoice(Pn_Org_Id              => Lr_Recode.Scux_Org_Id
                           ,Pv_Cm_Trx_Number       => Lr_Recode.Cm_Trx_Number
                           ,Pn_Cm_Customer_Trx_Id  => Lr_Recode.Cm_Customer_Trx_Id
                           ,Pv_Inv_Trx_Number      => Lr_Recode.Inv_Trx_Number
                           ,Pn_Inv_Customer_Trx_Id => Lr_Recode.Inv_Customer_Trx_Id
                           ,Pd_Reversal_Gl_Date    => Lr_Recode.Reversal_Gl_Date
                           ,Xv_Ret_Status          => Lv_Ret_Status
                           ,Xv_Ret_Message         => Lv_Ret_Msg);
      IF Lv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        UPDATE Scux_Sie_Ar_Unapp_Cm_Iface h
           SET h.Scux_Process_Step    = Lv_Procedure_Name
              ,h.Scux_Process_Date    = SYSDATE
              ,h.Scux_Process_Status  = Gv_Error
              ,h.Scux_Process_Message = Substrb(Lv_Ret_Msg
                                               ,0
                                               ,240)
         WHERE h.Rowid = Lr_Recode.Row_Id;
      ELSE
        UPDATE Scux_Sie_Ar_Unapp_Cm_Iface h
           SET h.Scux_Process_Step   = Lv_Procedure_Name
              ,h.Scux_Process_Date   = SYSDATE
              ,h.Scux_Process_Status = Gv_Completed
         WHERE h.Rowid = Lr_Recode.Row_Id;
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
  END Do_Process_Interface;

  /*===============================================================
  Program Name:   Do_Trim_Data
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
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
  V1.0      2018-09-19    SIE 谭家俊         Creation 
  V1.1      2018-12-17    SIE  郭剑          修订              
  ===============================================================*/
  PROCEDURE Do_Trim_Data(Pn_Scux_Session_Id  IN NUMBER
                        ,Pv_Scux_Source_Code IN VARCHAR
                        ,Xv_Ret_Status       OUT VARCHAR2
                        ,Xv_Ret_Message      OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Trim_Data';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    --Lv_Ret_Status     VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    --Lv_Ret_Message    VARCHAR2(2000);
    --v_Count           NUMBER;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    Gn_Main_Request_Id := Fnd_Global.Conc_Request_Id;
    UPDATE Scux_Sie_Ar_Unapp_Cm_Iface
       SET Scux_Interface_Header_Id = TRIM(Scux_Interface_Header_Id)
          ,Scux_Session_Id          = TRIM(Scux_Session_Id)
          ,Scux_Source_Code         = TRIM(Scux_Source_Code)
          ,Scux_Source_Num          = TRIM(Scux_Source_Num)
          ,Scux_Source_Id           = TRIM(Scux_Source_Id)
          ,Scux_Process_Group_Id    = TRIM(Scux_Process_Group_Id)
          ,Scux_Process_Step        = Lv_Procedure_Name --V1.1 TRIM(Scux_Process_Step)
          ,Scux_Process_Status      = Nvl(Scux_Process_Status
                                         ,Gv_Pending)
          ,Scux_Process_Date        = Nvl(TRIM(Scux_Process_Date)
                                         ,SYSDATE)
          ,Scux_Process_Message     = TRIM(Scux_Process_Message)
          ,Scux_Org_Name            = TRIM(Scux_Org_Name)
          ,Scux_Org_Id              = TRIM(Scux_Org_Id)
          ,Cm_Trx_Number            = TRIM(Cm_Trx_Number)
          ,Cm_Customer_Trx_Id       = TRIM(Cm_Customer_Trx_Id)
          ,Inv_Trx_Number           = TRIM(Inv_Trx_Number)
          ,Inv_Customer_Trx_Id      = TRIM(Inv_Customer_Trx_Id)
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
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   应收贷项发票取消核销主程序入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--状态
              Xv_Ret_Message       OUT VARCHAR2--错误信息
  Description: 应收贷项发票取消核销主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
  ===============================================================*/
  PROCEDURE Do_Import(Pn_Scux_Session_Id  IN NUMBER
                     ,Pv_Scux_Source_Code IN VARCHAR
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'Y' --是否初始化环境
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2) IS
  
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Import';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
    --Lv_Ret_Status     VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    --Lv_Ret_Message    VARCHAR2(2000);
    --Lv_Ret_Msg_Count  NUMBER;
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
                     ,'3.调用标准API处理接口数据：-----------');
    Do_Process_Interface(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
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
  Author      :   SIE 谭家俊
  Created:    :   2018-09-19
  Purpose     :   应收贷项发票取消核销并发调用入口
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --数据批次ID
              Pv_Scux_Source_Code  IN VARCHAR2 --数据来源
              Pv_Init_Flag         IN VARCHAR2 --外围系统调用需要初始化环境
              Pv_Debug_Flag        IN VARCHAR2 --开启诊段模试
              
  Return  :
              Errbuf               OUT VARCHAR2--状态
              Retcode              OUT VARCHAR2--错误信息
  Description: 应收贷项发票取消核销主程序入口
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-19    SIE 谭家俊         Creation    
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
  
    Lv_Ret_Status  VARCHAR2(30) := Fnd_Api.g_Ret_Sts_Success;
    Lv_Ret_Message VARCHAR2(2000);
    --Ln_Ret_Msg_Count NUMBER;
  
  BEGIN
    Retcode := Scux_Fnd_Log.Gv_Retcode_Exc_Success;
    Scux_Fnd_Log.Conc_Log_Header;
  
    Gn_Main_Request_Id := Fnd_Global.Conc_Request_Id;
  
    Do_Import(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
             ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
             ,Pv_Init_Flag        => Pv_Init_Flag
             ,Xv_Ret_Status       => Lv_Ret_Status
             ,Xv_Ret_Message      => Lv_Ret_Message);
    Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status => Lv_Ret_Status);
  
    Scux_Fnd_Log.Conc_Log_Footer;
  EXCEPTION
    --Standard SRS Main Exception Handler
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Srs_Exception(Pv_Api  => Lv_Api
                                             ,Errbuf  => Errbuf
                                             ,Retcode => Retcode);
  END Main;
END Scux_Sie_Ar_Unapply_Cm_Imp_Pkg;
/
