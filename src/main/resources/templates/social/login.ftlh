<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>Title</title>
</head>
<body>
    <button onclick="popupKakaoLogin()">KakaoLogin</button>
    <script>
        function popupKakaoLogin() {
            window.open('${loginUrl}', 'popupKakaoLogin', 'width=700,height=500,scrollbars=0,toolbar=0,menubar=no')
        }
    </script>
</body>
</html>
