CREATE PROC sp_XoaDocGia
    @ma_docgia_xoa SMALLINT
AS
BEGIN
    -- [1] Kiểm tra xem độc giả có tồn tại hay ko? Nếu không thì Thông báo "Không tồn tại độc giả" và Kết thúc proc
    IF NOT EXISTS (
        SELECT 1 FROM docgia AS dg 
        WHERE dg.ma_docgia = @ma_docgia_xoa
    )
    BEGIN
        PRINT N'Không tồn tại độc giả!'
        RETURN
    END

    -- [2] Kiểm tra độc giả có đang mượn sách hay ko? Nếu có thì Thông báo "Không thể xoá độc giả được" và Kết thúc proc
    IF EXISTS (
        SELECT * FROM muon AS m 
        WHERE m.ma_docgia = @ma_docgia_xoa
    )
    BEGIN
        PRINT N'Không thể xoá độc giả được!'
        RETURN
    END

    BEGIN TRANSACTION
    -- [3] Kiểm tra xem độc giả này là độc giả người lớn hay trẻ em
        -- [3.1] Nếu là người lớn:
        IF EXISTS (
            SELECT * FROM nguoilon AS nl 
            WHERE nl.ma_docgia = @ma_docgia_xoa
        )
            -- [3.1.1] Kiểm tra xem độc giả có bảo lãnh trẻ em nào hay ko?
            -- [3.1.2] Nếu ko bảo lãnh trẻ em thì xoá độc giả này
            -- Lưu ý: thứ tự xoá các bảng trên phải tuân thủ ràng buộc khoá ngoại. Ta phải xoá trên các bảng nguoilon / treem, bảng QuaTrinhMuon, bảng DangKy sau đó mới được xoá trong bảng DocGia
            IF NOT EXISTS (
                SELECT 1 FROM treem AS te
                WHERE te.ma_docgia_nguoilon = @ma_docgia_xoa
            )
            BEGIN
                -- [3.1.2.1] Xoá trong bảng NguoiLon, bảng QuanTrinhMuon, bảng DangKy
                DELETE FROM nguoilon WHERE ma_docgia = @ma_docgia_xoa
                DELETE FROM qtrinhmuon WHERE ma_docgia = @ma_docgia_xoa
                DELETE FROM dangky WHERE ma_docgia = @ma_docgia_xoa
                -- [3.1.2.2] Sau cùng là xoá trong bảng DocGia
                DELETE FROM docgia WHERE ma_docgia = @ma_docgia_xoa
            END

            -- [3.1.3] Nếu có bảo lãnh trẻ em thì:
            ELSE
            BEGIN
                -- [3.1.3.1] Tìm các trẻ em mà độc giả này bảo lãnh và xoá các trẻ em này
                DELETE FROM treem WHERE ma_docgia_nguoilon = @ma_docgia_xoa
                -- [3.1.3.2] Xoá trong bảng NguoiLon, bảng QuaTrinhMuon, bảng DangKy
                DELETE FROM nguoilon WHERE ma_docgia = @ma_docgia_xoa
                DELETE FROM qtrinhmuon WHERE ma_docgia = @ma_docgia_xoa
                DELETE FROM dangky WHERE ma_docgia = @ma_docgia_xoa
                -- [3.1.3.3] Sau cùng là xoá trong bảng DocGia
                DELETE FROM docgia WHERE ma_docgia = @ma_docgia_xoa
            END

        -- [3.2] Nếu là trẻ em thì xoá trong bảng TreEm, bảng QuaTrinhMuon, bảng DangKy
        ELSE
        BEGIN
            -- [3.2.1] Xoá trong bảng TreEm, bảng QuaTrinhMuon, bảng DangKy
            DELETE FROM treem WHERE ma_docgia_nguoilon = @ma_docgia_xoa
            DELETE FROM qtrinhmuon WHERE ma_docgia = @ma_docgia_xoa
            DELETE FROM dangky WHERE ma_docgia = @ma_docgia_xoa
            -- [3.2.2] Sau cùng là xoá trong bảng DocGia
            DELETE FROM docgia WHERE ma_docgia = @ma_docgia_xoa
        END
    COMMIT TRANSACTION
END
