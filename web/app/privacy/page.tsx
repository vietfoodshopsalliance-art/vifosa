export const metadata = {
  title: 'Chính sách quyền riêng tư — Viet Shops',
}

export default function PrivacyPage() {
  return (
    <main style={{ maxWidth: 720, margin: '0 auto', padding: '48px 24px', fontFamily: 'sans-serif', lineHeight: 1.7, color: '#222' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Chính sách quyền riêng tư</h1>
      <p style={{ color: '#666', marginBottom: 32 }}>Cập nhật lần cuối: 24/05/2026</p>

      <p>
        Ứng dụng <strong>Viet Shops</strong> ("chúng tôi") được phát triển bởi <strong>Vifosa</strong>.
        Trang này thông báo cho bạn về chính sách của chúng tôi liên quan đến việc thu thập, sử dụng
        và tiết lộ Dữ liệu Cá nhân khi bạn sử dụng Dịch vụ của chúng tôi.
      </p>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>1. Thông tin chúng tôi thu thập</h2>
      <p>Khi sử dụng ứng dụng, chúng tôi có thể thu thập các thông tin sau:</p>
      <ul>
        <li><strong>Thông tin tài khoản:</strong> Họ tên, số điện thoại, địa chỉ email khi bạn đăng ký.</li>
        <li><strong>Thông tin vị trí:</strong> Vị trí GPS để tìm cửa hàng gần bạn và giao hàng. Chúng tôi chỉ truy cập vị trí khi bạn cấp quyền.</li>
        <li><strong>Thông tin đơn hàng:</strong> Lịch sử đặt hàng, địa chỉ giao hàng.</li>
        <li><strong>Thông tin thiết bị:</strong> Token thiết bị để gửi thông báo đẩy (push notification).</li>
      </ul>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>2. Mục đích sử dụng</h2>
      <p>Chúng tôi sử dụng thông tin để:</p>
      <ul>
        <li>Cung cấp và vận hành dịch vụ đặt đồ ăn.</li>
        <li>Xử lý và giao đơn hàng của bạn.</li>
        <li>Gửi thông báo về trạng thái đơn hàng.</li>
        <li>Cải thiện chất lượng ứng dụng.</li>
        <li>Liên hệ hỗ trợ khi cần thiết.</li>
      </ul>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>3. Chia sẻ thông tin</h2>
      <p>
        Chúng tôi <strong>không bán</strong> dữ liệu cá nhân của bạn cho bên thứ ba.
        Thông tin chỉ được chia sẻ với các cửa hàng đối tác khi cần thiết để xử lý đơn hàng của bạn.
      </p>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>4. Bảo mật dữ liệu</h2>
      <p>
        Chúng tôi áp dụng các biện pháp bảo mật hợp lý để bảo vệ thông tin của bạn.
        Tuy nhiên, không có phương thức truyền dữ liệu qua Internet nào là an toàn tuyệt đối.
      </p>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>5. Quyền của bạn</h2>
      <p>Bạn có quyền:</p>
      <ul>
        <li>Truy cập và chỉnh sửa thông tin cá nhân trong phần Hồ sơ của ứng dụng.</li>
        <li>Yêu cầu xóa tài khoản và dữ liệu bằng cách liên hệ chúng tôi.</li>
        <li>Thu hồi quyền truy cập vị trí bất kỳ lúc nào trong Cài đặt điện thoại.</li>
      </ul>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>6. Dịch vụ bên thứ ba</h2>
      <p>Ứng dụng sử dụng Firebase (Google) để xử lý thông báo đẩy. Vui lòng tham khảo{' '}
        <a href="https://policies.google.com/privacy" style={{ color: '#1a73e8' }}>Chính sách quyền riêng tư của Google</a>.
      </p>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>7. Liên hệ</h2>
      <p>
        Nếu có thắc mắc về chính sách này, vui lòng liên hệ:<br />
        📧 <a href="mailto:dmtri.nc@gmail.com" style={{ color: '#1a73e8' }}>dmtri.nc@gmail.com</a>
      </p>
    </main>
  )
}
