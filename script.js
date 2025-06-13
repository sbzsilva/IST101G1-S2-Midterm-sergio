const smallCups = document.querySelectorAll('.cup-small')
const liters = document.getElementById('liters')
const percentage = document.getElementById('percentage')
const remained = document.getElementById('remained')

updateBigCup()

smallCups.forEach((cup, idx) => {
    cup.addEventListener('click', () => highlightCups(idx))
})

function highlightCups(idx) {
    if (idx === 7 && smallCups[idx].classList.contains("full")) idx--;
    else if (smallCups[idx].classList.contains('full') && !smallCups[idx].nextElementSibling.classList.contains('full')) {
        idx--
    }

    smallCups.forEach((cup, idx2) => {
        if (idx2 <= idx) {
            cup.classList.add('full')
        } else {
            cup.classList.remove('full')
        }
    })

    updateBigCup()
}

function updateBigCup() {
    const fullCups = document.querySelectorAll('.cup-small.full').length
    const totalCups = smallCups.length

    if (fullCups === 0) {
        percentage.style.visibility = 'hidden'
        percentage.style.height = 0
    } else {
        percentage.style.visibility = 'visible'
        percentage.style.height = `${(fullCups / totalCups) * 100}%`
        percentage.innerText = `${(fullCups / totalCups) * 100}%`
    }

    if (fullCups === totalCups) {
        remained.style.visibility = 'hidden'
        remained.style.height = 0
    } else {
        remained.style.visibility = 'visible'
        liters.innerText = `${2 - (250 * fullCups / 1000)}L`
    }
}

// Improved IP Fetching with multiple fallback APIs
function fetchPublicIP() {
  const ipApis = [
    'https://api.ipify.org?format=json',
    'https://ipapi.co/json/',
    'https://ipinfo.io/json'
  ];
  
  const tryApi = async (index = 0) => {
    try {
      const response = await fetch(ipApis[index]);
      if (!response.ok) throw new Error('API failed');
      const data = await response.json();
      document.getElementById('ec2-ip').textContent = `Server IP: ${data.ip || data.ipAddress}`;
    } catch (error) {
      if (index < ipApis.length - 1) {
        tryApi(index + 1);
      } else {
        document.getElementById('ec2-ip').textContent = 'Server IP: Not Available';
        console.error('All IP APIs failed:', error);
      }
    }
  };
  
  tryApi(0);
}

// Function to update the date and time
function updateDateTime() {
  const now = new Date();
  const datetimeElement = document.getElementById('datetime');
  if (datetimeElement) {
    datetimeElement.textContent = now.toLocaleString();
  }
}

// Initialize everything
fetchPublicIP();
updateDateTime();
setInterval(updateDateTime, 1000);