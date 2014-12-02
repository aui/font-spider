module.exports = function Contextify (window) {
	window.getGlobal = function () {
		return window;
	};
	window.dispose = function () {
		delete window.getGlobal;
		delete window.dispose;
		window = null;
	}
};