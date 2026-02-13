import React from 'react';

const App: React.FC = () => {
  return (
    <div className="min-h-screen bg-black text-green-500 font-mono p-4">
      <h1 className="text-xl">Termux Alist Bot (Android)</h1>
      <p className="mt-4 border-b border-gray-700 pb-2">Scripts Restored for Termux Environment.</p>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mt-6">
        <div>
          <h3 className="text-white font-bold mb-3">📂 Core Scripts</h3>
          <ul className="list-disc ml-5 text-gray-400 space-y-1">
            <li><span className="text-green-400">setup.sh</span>: Uses `pkg` to install dependencies.</li>
            <li><span className="text-green-400">start.sh</span>: Optimized for Android shell.</li>
            <li><span className="text-green-400">ecosystem.config.js</span>: PM2 service config.</li>
          </ul>
        </div>

        <div>
          <h3 className="text-white font-bold mb-3">🤖 Features</h3>
          <ul className="list-disc ml-5 text-gray-400 space-y-1">
            <li><span className="text-blue-400">System Monitor</span>: Check CPU/RAM/Disk on phone.</li>
            <li><span className="text-blue-400">/dl &lt;url&gt;</span>: Download files to phone storage.</li>
            <li><span className="text-blue-400">Tunnel</span>: Free Cloudflare public URL.</li>
          </ul>
        </div>
      </div>

      <div className="mt-8 p-4 bg-gray-900 rounded border border-gray-800">
        <h4 className="text-white font-bold">Termux Quick Start:</h4>
        <code className="block mt-2 text-sm text-yellow-500">
          termux-setup-storage<br/>
          chmod +x setup.sh start.sh<br/>
          ./setup.sh<br/>
          nano ~/.env<br/>
          ./start.sh
        </code>
      </div>
    </div>
  );
};

export default App;