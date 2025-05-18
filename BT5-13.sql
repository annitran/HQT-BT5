CREATE PROC sp_TraSach 
    @ma_docgia_trasach SMALLINT,
    @ma_cuonsach_tra SMALLINT
AS
BEGIN
    -- [1] Xác định tiền phạt nếu trả quá hạn (= 1000 * số ngày trễ hạn)
    DECLARE @so_ngay_tre_han INT
    SELECT @so_ngay_tre_han = DATEDIFF(DAY, m.ngay_hethan, GETDATE())
    FROM muon AS m
    WHERE m.ma_cuonsach = @ma_cuonsach_tra AND m.ma_docgia = @ma_docgia_trasach

    BEGIN TRANSACTION
        DECLARE @tien_phat money = 0

        IF (@so_ngay_tre_han > 0)
        BEGIN
            SET @tien_phat = 1000 * @so_ngay_tre_han
        END

    -- [2] Thêm vào bảng quá trình mượn
        INSERT INTO qtrinhmuon (isbn, ma_cuonsach, ma_docgia, ngay_muon, ngay_hethan, ngay_tra, tien_phat)
        SELECT m.isbn, @ma_cuonsach_tra, @ma_docgia_trasach, m.ngay_muon, m.ngay_hethan, GETDATE(), @tien_phat
        FROM muon AS m 
        WHERE m.ma_cuonsach = @ma_cuonsach_tra AND m.ma_docgia = @ma_docgia_trasach

    -- [3] Xoá dữ liệu trong bảng mượn
        DELETE FROM muon 
        WHERE ma_cuonsach = @ma_cuonsach_tra AND ma_docgia = @ma_docgia_trasach

        PRINT N'Thành công!!!'
        COMMIT TRANSACTION
END
