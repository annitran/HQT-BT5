CREATE PROC sp_MuonSach
    @ma_cuonsach_muon SMALLINT,
    @ma_docgia_muon SMALLINT
AS
BEGIN
    -- [1] Kiểm tra độc giả có đang mượn quyển sách cùng loại ko? Nếu có:
    IF EXISTS (
        SELECT 1 FROM muon AS m 
        WHERE m.ma_cuonsach = @ma_cuonsach_muon
    )
    BEGIN
        -- [1.1] Thông báo lỗi
        PRINT N'Độc giả này đang mượn quyển sách này!'
        -- [1.2] Return
        RETURN
    END

    -- [2] Nếu không: Kiểm tra số lượng sách độc giả đang mượn:
        -- [2.1] Kiểm tra độc giả là người lớn hay trẻ em?
        IF EXISTS (
            SELECT 1 FROM nguoilon AS nl
            WHERE nl.ma_docgia = @ma_docgia_muon
        )
        BEGIN
            -- Nếu là người lớn:
            DECLARE @SL_sach_dangmuon INT
            DECLARE @sach_nguoilon_dangmuon INT
            DECLARE @sach_treem_dangmuon INT
            -- tính tổng số sách độc giả đang mượn
            SELECT @sach_nguoilon_dangmuon = COUNT(*) 
            FROM muon 
            WHERE ma_docgia = @ma_docgia_muon
            -- và trẻ em do độc giả bảo lãnh mượn (nếu có)
            SELECT @sach_treem_dangmuon = COUNT(*)
            FROM muon AS m 
            JOIN treem AS te ON te.ma_docgia = m.ma_docgia
            WHERE te.ma_docgia_nguoilon = @ma_docgia_muon
            -- tổng số sách đang mượn
            SET @SL_sach_dangmuon = ISNULL(@sach_nguoilon_dangmuon, 0) + ISNULL(@sach_treem_dangmuon, 0)

            -- Nếu = 5 thì: Báo lỗi và return
            IF (@SL_sach_dangmuon = 5)
            BEGIN
                PRINT N'Độc giả này đã mượn đủ số lượng 5 quyển sách!'
                RETURN
            END
        END

        -- [2.2] Nếu là trẻ em: tính số sách trẻ em đang mượn:
        ELSE
        BEGIN
            -- [2.2.1] Nếu < 1:
            IF NOT EXISTS (
                SELECT 1 FROM muon AS m 
                WHERE m.ma_docgia = @ma_docgia_muon
            )
            BEGIN
                DECLARE @new_ma_docgia_nguoilon SMALLINT
                DECLARE @SL_sach_nguoilon_muon INT

                -- lấy mã người lớn bảo lãnh
                SELECT @new_ma_docgia_nguoilon = te.ma_docgia_nguoilon
                FROM treem AS te 
                WHERE te.ma_docgia = @ma_docgia_muon
                -- tính số sách người lớn bảo lãnh cho trẻ em này
                SELECT @SL_sach_nguoilon_muon = COUNT(*) 
                FROM muon
                WHERE ma_docgia = @new_ma_docgia_nguoilon

                -- [2.2.1.1] Nếu = 5 thì báo lỗi và return
                IF (@SL_sach_nguoilon_muon = 5)
                BEGIN
                    PRINT N'Người lớn của độc giả này đã mượn đủ số lượng 5 quyển sách!'
                    RETURN
                END
            END
            -- [2.2.2] Nếu = 1 thì báo lỗi và return
            ELSE
            BEGIN
                PRINT N'Độc giả trẻ em này đã mượn đủ số lượng sách!'
                RETURN
            END
        END
    
    -- [3] Kiểm tra có còn sách trong thư viện ko?
    BEGIN TRANSACTION
        -- [3.1] Nếu còn:
        IF EXISTS (
            SELECT 1 FROM cuonsach AS cs 
            WHERE cs.ma_cuonsach = @ma_cuonsach_muon AND cs.tinhtrang = 'Y'
        )
        BEGIN
            -- [3.1.1] Thêm 1 record vào bảng mượn
            DECLARE @ISBN INT
            SELECT @ISBN = cs.isbn
            FROM cuonsach AS cs 
            WHERE cs.ma_cuonsach = @ma_cuonsach_muon

            INSERT INTO muon 
            VALUES (@ISBN, @ma_cuonsach_muon, @ma_docgia_muon, GETDATE(), DATEADD(DAY, 14, GETDATE()))
            -- [3.1.2] Cập nhật tình trạng cuốn sách
            UPDATE cuonsach
            SET tinhtrang = 'N'
            WHERE ma_cuonsach = @ma_cuonsach_muon
            -- [3.1.3] Cập nhật trạng thái đầu sách
            EXEC sp_CapnhatTrangthaiDausach
            -- [3.1.4] Thông báo mượn sách thành công
            PRINT N'Mượn sách thành công!'
            
            COMMIT TRANSACTION
        END

        -- [3.2] Nếu ko còn:
        ELSE
        BEGIN
            -- Gán isbn từ mã cuốn sách (nếu có)
            SELECT @ISBN = isbn
            FROM cuonsach
            WHERE ma_cuonsach = @ma_cuonsach_muon
            -- [3.2.1] Thông báo cho độc giả chờ
            PRINT N'Sách này đã hết! Xin chờ lần sau!'
            -- [3.2.2] Thêm 1 record vào bảng DangKy
            INSERT INTO dangky (isbn, ma_docgia, ngay_dk, ghichu)
            VALUES (@ISBN, @ma_docgia_muon, GETDATE(), 'Độc giả đăng ký mượn sách này!')
            
            COMMIT TRANSACTION
        END
END
