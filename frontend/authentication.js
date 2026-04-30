// ── Auth Module ─────────────────────────────────────────────
const Auth = (() => {
    // authentication.js
    const COGNITO_DOMAIN = CONFIG.COGNITO_DOMAIN;
    const COGNITO_CLIENT_ID = CONFIG.CLIENT_ID;
    const REDIRECT_URI = CONFIG.REDIRECT_URI;

    const LOGIN_URL = `${COGNITO_DOMAIN}/login?client_id=${COGNITO_CLIENT_ID}&response_type=code` +
        `&scope=email+openid+phone&redirect_uri=${encodeURIComponent(REDIRECT_URI)}`;

    const LOGOUT_URL = `${COGNITO_DOMAIN}/logout?client_id=${COGNITO_CLIENT_ID}` +
        `&logout_uri=${encodeURIComponent(REDIRECT_URI)}`;

    // ── Helpers ──────────────────────────────────────────────
    function parseJwt(token) {
        try {
            return JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
        } catch {
            return null;
        }
    }

    function isExpired(token) {
        const decoded = parseJwt(token);
        if (!decoded?.exp) return true;

        const now = Math.floor(Date.now() / 1000);
        return decoded.exp < now;
    }

    function saveTokens(tokens) {
        sessionStorage.setItem("id_token", tokens.id_token);
        sessionStorage.setItem("access_token", tokens.access_token);
        if (tokens.refresh_token) {
            sessionStorage.setItem("refresh_token", tokens.refresh_token);
        }

        const claims = parseJwt(tokens.id_token);
        sessionStorage.setItem("user_email", claims?.email || "");
        sessionStorage.setItem("user_name", claims?.["cognito:username"] || "");
    }

    function clear() {
        sessionStorage.clear();
    }

    // ── Token Exchange ───────────────────────────────────────
    async function exchangeCode(code) {
        const resp = await fetch(`${COGNITO_DOMAIN}/oauth2/token`, {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: new URLSearchParams({
                grant_type: "authorization_code",
                client_id: COGNITO_CLIENT_ID,
                redirect_uri: REDIRECT_URI,
                code,
            }),
        });

        const data = await resp.json();
        if (!data.id_token) throw new Error("Token exchange failed");

        saveTokens(data);
    }

    async function refresh() {
        const refreshToken = sessionStorage.getItem("refresh_token");
        if (!refreshToken) return false;

        try {
            const resp = await fetch(`${COGNITO_DOMAIN}/oauth2/token`, {
                method: "POST",
                headers: { "Content-Type": "application/x-www-form-urlencoded" },
                body: new URLSearchParams({
                    grant_type: "refresh_token",
                    client_id: COGNITO_CLIENT_ID,
                    refresh_token: refreshToken,
                }),
            });

            const data = await resp.json();

            if (data.id_token) {
                console('new tokens obtained using refresh-token, saving them to session storage');
                saveTokens(data);
                return true;
            }
        } catch (e) {
            console.error("Refresh failed", e);
        }

        return false;
    }

    // ── Public API ───────────────────────────────────────────
    async function ensureAuth() {
        const params = new URLSearchParams(window.location.search);
        const code = params.get("code");

        // Step 1: Handle redirect from Cognito
        if (code) {
            try {
                await exchangeCode(code);
            } catch (e) {
                console.error(e);
                clear();
                window.location.href = LOGIN_URL;
                return false;
            }

            window.history.replaceState({}, "", "/");
            return true;
        }

        // Step 2: Check existing session
        let idToken = sessionStorage.getItem("id_token");

        if (!idToken) {
            window.location.href = LOGIN_URL;
            return false;
        }

        // Step 3: If expired → try refresh
        if (isExpired(idToken)) {
            const refreshed = await refresh();

            if (!refreshed) {
                clear();
                window.location.href = LOGIN_URL;
                return false;
            }

            idToken = sessionStorage.getItem("id_token");
        }

        return true;
    }

    async function getValidIdToken() {
        let idToken = sessionStorage.getItem("id_token");

        if (!idToken) {
            window.location.href = LOGIN_URL;
            return null;
        }

        if (isExpired(idToken)) {
            console.log('id token is expired, getting new token using the refresh-token');
            const refreshed = await refresh();

            if (!refreshed) {
                clear();
                window.location.href = LOGIN_URL;
                return null;
            }

            idToken = sessionStorage.getItem("id_token");
        }

        return idToken;
    }

    function getUserEmail() {
        return sessionStorage.getItem("user_email") || "";
    }

    function getUserName() {
        return sessionStorage.getItem("user_name") || "";
    }

    function signOut() {
        clear();
        window.location.href = LOGOUT_URL;
    }

    return {
        ensureAuth,
        getUserEmail,
        getUserName,
        signOut,
        getValidIdToken
    };
})();

document.getElementById("signout-btn").addEventListener("click", Auth.signOut);