# ___PLSQL学习___

## ___PLSQL基本结构___
---
<div style="font-size:15px;color:pink;font-family:'楷体'">

### ___PLSQL代码示例：___
```
DECLARE
  temp VARCHAR2 := 'Hello World!';
BEGIN
  DBMS_OUTPUT.PUT_LINE();  
EXCEPTION
  NULL;      
END;
```

### ___示例解释___
1. declare后面跟声明变量<br>
2. begin ... end里填写执行逻辑<br>
3. exception后面跟异常处理

</div>

## ___PLSQL标识符___
---

<div style="font-size:15px;color:green;font-family:'楷体'">

### ___PLSQL标识演示：___

四则运算：+ - * /<br>
属性绑定：%<br>
字符串分隔符：'<br>
组件选择符：.<br>
表达式列表分隔符：(,)<br>
主机变量指示符：：<br>
项目分隔符：,<br>
引用标识符分隔符："<br>
关系运算符：=<br>
远程访问指示符：@<br>
终止符：;<br>
赋值：:=<br>
关联：=><br>
连接：||<br>
指数：**<br>
标签分隔符：<< >><br>
多行注释：/* */<br>
单行注释：--<br>
范围注释：..<br>
关系运算：< > <= >=<br>
不等运算：<> '= ~= ^=

</div>

## ___PLSQL程序单元___
---
<div style="font-size:15px;color:yellow;font-family:'楷体'">

### ___分类___

1. PL/SQL块
2. 函数
3. 包
4. 过程
5. 触发器
6. 类型
7. 类型体
</div>


## ___PLSQL数据类型___
---

<div style="font-size:15px;color:aqua;font-family:'楷体'">

### ___分类___
1. 标量：没有内部组件的单个值，如number、date、boolean
2. 大对象：指向与其他数据项（文本、图像、视频、音频）分开存储的大对象的指针
3. 复合类型：具有可以单独访问的内部组件数据项。例如，集合和记录
4. 引用类型：指向其他数据项

### ___标量___
1. 数字：NUMBER包括其子类型们，整型（BINARY_INTEGER）、浮点型（BINARY_FLOAT、BINARY_DOUBLE）
2. 字符：定长字符串（NCHAR、CHAR）、变长字符串（NVARCHAR2、VARCHAR2）
3. 布尔：BOOLEAN，可选值为TRUE、FALSE、NULL，SQL语句中不支持该类型
4. 日期：DATE类型数据值，年（YEAR）、月（MONTH）、日（DAY）、时（HOUR）、分（MINUTE）、秒（SECOND）
5. 大对象：二进制大对象（BLOB）、字符大对象（CLOB）
</div>

## ___PLSQL变量及常量___
---

<div style="font-size:15px;color:orange;font-family:'楷体'">

### ___变量命名规则___
- 美刀（$）、字母（ABC）、数字（123）、下划线（_）。长度不能超过30个字符，一般不区分大小写。不能涉及PLSQL中的保留关键字

### ___变量声明___
- 可在包（PACKAGE）、函数（FUNCTION）、过程（PROCEDURE）或者声明块（DECLARE）中声明变量

### ___PLSQL作用域___
1. 局部变量：内部块中声明的变量，外部块不可访问
2. 全局变量：在最外部块或包声明的变量

### ___声明常量___
1. 使用`CONSTANT`关键字声明常量。声明常量需要初始化常量值，并且常量不可在初始化后再次赋值更改

</div>

## ___PLSQL运算符___
---

<div style="font-size:15px;color:fuchsia;font-family:'楷体'">

### ___运算符___
1. 算数运算符：加（+）减（-）乘（*）除取（/）指数（**）
2. 关系运算符：相等（=）不等（<>）大于（>）小于（<）大于等于（>=）小于等于（<=）
3. 比较运算符：LIKE、BETWEEN、IN、IS NULL
4. 逻辑运算符：AND、OR、NOT
</div>

## ___PLSQL条件控制___
---

<div style="font-size:15px;color:olive;font-family:'楷体'">

### ___IF...THEN...ELSIF...ELSE...END IF语句块___
```
IF 表达式 THEN
  执行语句;
ELSIF 表达式分支 THEN
  分支执行语句;
ELSE
  其他情况执行语句;
END IF;
```

### ___CASE...WHEN...THEN...ELSE...END CASE语句块___
- #### ___CASE语句___
```
CASE 表达式
  WEHN 值1 THEN 执行操作1;
  WHEN 值2 THEN 执行操作2;
  ELSE 以上值都不匹配执行操作;
END CASE;  
```
- #### ___搜索CASE语句___
```
CASE
  WHEN 表达式1 THEN 操作1;
  WHEN 表达式2 THEN 执行操作2;
  ELSE 以上值都不匹配执行操作;
END CASE;
```

</div>

## ___PLSQL循环___
---

<div style="font-size:15px;color:violet;font-family:'楷体'">

### ___LOOP循环___
```
LOOP
    循环体;
    IF 退出循环条件 THEN
      EXIT;
    END IF;
END LOOP;
或者
LOOP
    循环体;
    EXIT WHEN 退出条件;
END LOOP;
```

### ___WHILE...LOOP循环___
```
WHILE 进入循环的条件 LOOP
    循环体;
END LOOP;
```

### ___FOR...LOOP___
```
FOR 变量 IN 下限..上限 LOOP
  DBMS_OUTPUT.PUT_LINE(变量);
END LOOP;

--反转FOR...LOOP语句

FOR 变量 IN REVERSE 下限..上限 LOOP
  DBMS_OUTPUT.PUT_LINE(变量);
END LOOP;

```

</div>


## ___PLSQL字符串函数及运算符___
---

<div style="font-size:15px;color:wheat;font-family:'楷体'">

### ___字符串函数___
1. ASCII(X)：返回字符对应的ASCII值
2. CHR(X)：返回ASCII值等于X的字符
3. CONCAT(X,Y)：XY字符串拼接
4. INITCAP(X)：X首字母大写
5. INSTR(X,搜索子串,开始位置,返回第几次出现的字符位置)：搜索X字符串的子串位置并返回
6. LENGTH(X)：返回X字符长度
7. LENGTHB(X)：返回X的字节长度
8. LOWER(X)：返回X小写字符串
9. LPAD(X,限定宽度,填充字符)：给X填充字符到限定宽度，L代表左填充
10. LTRIM(X,裁切字符串)：裁切X左侧的指定字符串

</div>
