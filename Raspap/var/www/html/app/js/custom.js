function deepScanCheck() {
    // Disable the button immediately when clicked
    $('.deep-scan').prop('disabled', true);

    // Show the loading spinner
    $('#loading-spinner').show();

    // Initialize countdown in seconds
    let countdown = 70;

    // Display the initial countdown time in the specified format
const formatCountdown = (seconds) => {
    if (seconds >= 60) {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}min ${secs < 10 ? '0' : ''}${secs}s`;
    } else {
        return `${seconds}s`;
    }
};

    $('#evil-twin-alert').html(`
        <div class="col-lg-12">
            <div class="alert alert-warning d-flex align-items-center justify-content-between">
                <div class="d-flex align-items-center">
                    <h5 class="mb-0 me-2">Deep Analysis in Progress: Scanning Access Points.</h5>
                    <div class="spinner-grow spinner-grow-m me-5" role="status" aria-hidden="true">
                        <span class="sr-only">Loading...</span>
                    </div>
                </div>
                <div id="countdown-timer" class="text-start"><b>${formatCountdown(countdown)}</b></div>
            </div>
        </div>
    `);

    // Update countdown timer every second
    const timerInterval = setInterval(() => {
        countdown--;
        $('#countdown-timer').text(formatCountdown(countdown));

        // Stop the countdown when it reaches 0
        if (countdown <= 0) {
            clearInterval(timerInterval);
            $('#countdown-timer').text("Waiting for Results...");
        }
    }, 1000);

    // Make the AJAX call to check the deep scan
    $.get('ajax/networking/checkDeepScan.php', function(data) {
        try {
            var response = JSON.parse(data);

            // Clear the countdown if we receive a response before reaching 0
            clearInterval(timerInterval);

            // Reset the countdown display to "Completed" or any other desired state
            $('#countdown-timer').text("Completed");

            if (response.status === 0) {
                // Show alert for Evil Twin detection
                var alertHtml = '<div class="col-lg-12">' +
                                '<div class="alert alert-danger">' +
                                '<h4><b>Evil Twin Detected (Rogue Access Point)!</b></h4>';
                
                if (response.evil_twins) {
                    Object.values(response.evil_twins).forEach(function(evil_twin) {
                        if (evil_twin.SSID) {
                            alertHtml += '<p>Be cautious when connecting to <b><i>' + 
                                         evil_twin.SSID + '</i></b></p>';
                        }
                    });
                }
                
                alertHtml += '</div></div>';
                $('#evil-twin-alert').html(alertHtml);
            } else if (response.status === 1) {
                // Show success alert if no evil twins are detected
                var successAlertHtml = '<div class="col-lg-12">' +
                                       '<div class="alert alert-success">' +
                                       '<h4><b>Good To Go !</b></h4>' +
                                       '<p>Devices can safely connect to any Access Point.</p>' +
                                       '</div></div>';
                $('#evil-twin-alert').html(successAlertHtml);
            } else {
                // Clear alert if status is unrecognized
                console.log("Unrecognized status.");
                $('#evil-twin-alert').html('');
            }
        } catch (e) {
            console.error("Parsing error:", e);
        } finally {
            // Hide the loading spinner
            $('#loading-spinner').hide();
            // Re-enable the button after the request is completed
            $('.deep-scan').prop('disabled', false);
        }
    })
    .fail(function() {
        console.error("Error: Could not reach checkDeepScan.php");
        // Ensure the button is re-enabled and hide the loading spinner on failure
        $('#loading-spinner').hide();
        $('.deep-scan').prop('disabled', false);
    });
}

// Automatically run deepScanCheck on page load
$(document).ready(function() {
    if (window.location.pathname === '/wpa_conf') {
        deepScanCheck(); // Call the function to run it immediately

        $(".deep-scan").on("click", deepScanCheck); // Keep the button functionality
    }
});