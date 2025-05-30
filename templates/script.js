document.getElementById("urlForm").addEventListener("submit", async function(event) {
    event.preventDefault();

    const url = document.getElementById("urlInput").value;

    const formData = new URLSearchParams();
    formData.append("url", url);

    const response = await fetch("/shorten", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: formData.toString(),
    })

    const respText = await response.text()

    if (response.ok) {
        const shortUrl = window.location.origin + "/" + respText
        const elem = document.getElementById("shortUrlOutput")
        elem.innerHTML = shortUrl
        elem.href = shortUrl
    } else {
        console.log(`error: ${respText}`)
        alert(respText)
    }
});